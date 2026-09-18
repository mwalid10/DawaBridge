import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/connectivity.dart';
import '../../core/file_utils.dart';
import '../../core/offline_cache.dart';
import '../../core/rpc.dart';
import '../../core/supabase_client.dart';
import 'message.dart';
import 'outbox.dart';

/// Messages for one deal's thread — an initial page, then kept live via a
/// Realtime subscription. Sending relies on the subscription echoing the
/// insert back rather than an optimistic local append, so there's a single
/// source of truth for message order.
///
/// Fixed here:
///   * The initial fetch had no limit and pulled the entire thread.
///   * `_subscribe()` ran *after* the fetch awaited, so a message inserted
///     in between was lost until the screen was reopened.
class MessagesController extends AsyncNotifier<List<Message>> {
  MessagesController(this.dealId);

  static const _pageSize = 50;

  final String dealId;
  RealtimeChannel? _channel;
  StreamSubscription<void>? _outboxSub;
  bool _hasMore = true;
  bool _loadingMore = false;

  bool get hasMore => _hasMore;

  @override
  Future<List<Message>> build() async {
    ref.onDispose(() {
      _channel?.unsubscribe();
      _outboxSub?.cancel();
    });

    // Subscribe before fetching so nothing can slip through the gap; the id
    // check in the callback absorbs any overlap.
    _subscribe();

    // Re-render when the outbox drains, so a queued bubble stops looking
    // pending the moment it's actually delivered.
    _outboxSub ??= MessageOutbox.onChanged.listen((_) => unawaited(_syncPending()));

    final rows = await rpcList(
      'get_messages',
      params: {'p_deal_id': dealId, 'p_limit': _pageSize},
      // Threads are readable with no signal — the whole point of queuing a
      // reply is that you were reading the conversation when you lost it.
      cacheKey: OfflineCache.messages(dealId),
    );
    _hasMore = rows.length == _pageSize;

    // The RPC returns newest-first so it can page with a `before` cursor;
    // the thread renders oldest-first.
    final delivered = rows.map(Message.fromJson).toList().reversed.toList();
    final pending = await MessageOutbox.forDeal(dealId);
    return [...delivered, ...pending.map(Message.pending)];
  }

  /// Drops pending bubbles whose message has since been delivered.
  Future<void> _syncPending() async {
    final current = state.value;
    if (current == null) return;

    final stillQueued = (await MessageOutbox.forDeal(dealId)).map((m) => m.id).toSet();
    final next = current.where((m) => !m.isPending || stillQueued.contains(m.id)).toList();
    if (next.length != current.length) state = AsyncValue.data(next);
  }

  void _subscribe() {
    _channel?.unsubscribe();
    _channel = supabase
        .channel('messages-$dealId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'deal_id', value: dealId),
          callback: (payload) {
            final message = Message.fromJson(payload.newRecord);
            final current = state.value ?? [];
            // A queued message echoes back under the id we generated for
            // it, so replace the pending bubble rather than appending a
            // duplicate beside it.
            final pendingIndex = current.indexWhere((m) => m.id == message.id && m.isPending);
            if (pendingIndex != -1) {
              final next = [...current]..[pendingIndex] = message;
              state = AsyncValue.data(next);
              return;
            }
            if (current.any((m) => m.id == message.id)) return;
            state = AsyncValue.data([...current, message]);
          },
        )
        .subscribe();
  }

  /// Older messages, for scroll-back at the top of the thread.
  Future<void> loadOlder() async {
    if (_loadingMore || !_hasMore) return;
    final current = state.value ?? [];
    if (current.isEmpty) return;

    _loadingMore = true;
    try {
      final rows = await rpcList('get_messages', params: {
        'p_deal_id': dealId,
        'p_limit': _pageSize,
        'p_before': current.first.createdAt.toIso8601String(),
      });
      _hasMore = rows.length == _pageSize;

      final older = rows.map(Message.fromJson).toList().reversed.toList();
      final seen = current.map((m) => m.id).toSet();
      state = AsyncValue.data([...older.where((m) => !seen.contains(m.id)), ...current]);
    } finally {
      _loadingMore = false;
    }
  }

  /// Sends a message, queueing it if there's no connection.
  ///
  /// Chat is the one write the app queues offline. It's append-only, only
  /// its order within the thread matters, and nothing can change underneath
  /// it that would make a late delivery wrong — unlike accepting a deal,
  /// which stays online-only for exactly that reason.
  ///
  /// The row id is generated here rather than server-side so a retry whose
  /// first attempt actually landed collides on the primary key instead of
  /// posting the message twice. See [MessageOutbox].
  Future<void> send(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    // `body` is NOT NULL but had no length bound, so a paste could push an
    // arbitrarily large row through Realtime to the other device.
    final capped = trimmed.length > 4000 ? trimmed.substring(0, 4000) : trimmed;

    final pending = PendingMessage(
      id: MessageOutbox.newId(),
      dealId: dealId,
      senderId: uid,
      body: capped,
      createdAt: DateTime.now(),
    );

    if (connectivityController.isOffline) {
      await _enqueue(pending);
      return;
    }

    try {
      await supabase.from('messages').insert({
        'id': pending.id,
        'deal_id': dealId,
        'sender_id': uid,
        'body': capped,
      });
      connectivityController.reportSuccess();
    } catch (error) {
      if (!ConnectivityController.looksOffline(error)) rethrow;
      // Went offline between the check and the insert, or the interface is
      // up but nothing can actually get out.
      connectivityController.reportFailure();
      await _enqueue(pending);
    }
  }

  Future<void> _enqueue(PendingMessage pending) async {
    await MessageOutbox.add(pending);
    // Show it in the thread immediately, greyed, so the message doesn't
    // appear to vanish. The Realtime echo replaces it once it lands.
    final current = state.value ?? [];
    state = AsyncValue.data([...current, Message.pending(pending)]);
  }

  /// Uploads [localPath] to the deal-scoped chat-attachments path
  /// (`<dealId>/<uid>-<timestamp>.<ext>` — matches the participant-scoped
  /// RLS from 0014_messages_attachments.sql) and posts a message carrying
  /// just the storage path, not a public URL, since the bucket stays
  /// private; readers resolve it to a signed URL on demand.
  Future<void> sendAttachment(String localPath) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    // Checked client-side so the user is told immediately rather than after
    // pushing the whole file over a mobile connection and getting a 413
    // from the bucket limit added in migration 0040.
    final size = await fileSizeBytes(localPath);
    if (size != null && size > maxChatAttachmentBytes) {
      throw const _AttachmentTooLarge();
    }

    final path = '$dealId/$uid-${DateTime.now().microsecondsSinceEpoch}.${fileExtension(localPath)}';
    await supabase.storage.from('chat-attachments').upload(path, File(localPath));

    try {
      await supabase.from('messages').insert({
        'deal_id': dealId,
        'sender_id': uid,
        'body': '📎 Attachment',
        'attachment_path': path,
      });
    } catch (_) {
      // The upload happens first, so a failed insert used to leave the file
      // in the bucket with nothing referencing it — invisible, undeletable
      // from the app, and billable forever. 0014's participant delete
      // policy lets us clean up after ourselves.
      await supabase.storage.from('chat-attachments').remove([path]).catchError((_) => <FileObject>[]);
      rethrow;
    }
  }

  /// Posts the caller's current coordinates as a location-share message —
  /// rendered client-side as a small map preview (see _LocationPreview in
  /// chat_thread_screen.dart) rather than a generic attachment, so it needs
  /// its own columns instead of going through attachment_path.
  Future<void> sendLocation({required double lat, required double lng}) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    await supabase.from('messages').insert({
      'deal_id': dealId,
      'sender_id': uid,
      'body': '📍 Shared location',
      'location_lat': lat,
      'location_lng': lng,
    });
  }
}

/// Recognised by `AppError` via its message code.
class _AttachmentTooLarge implements Exception {
  const _AttachmentTooLarge();
  @override
  String toString() => 'FILE_TOO_LARGE';
}

final messagesControllerProvider =
    AsyncNotifierProvider.autoDispose.family<MessagesController, List<Message>, String>(
  (id) => MessagesController(id),
);
