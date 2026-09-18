import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/file_utils.dart';
import '../../core/rpc.dart';
import '../../core/supabase_client.dart';
import 'message.dart';

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
  bool _hasMore = true;
  bool _loadingMore = false;

  bool get hasMore => _hasMore;

  @override
  Future<List<Message>> build() async {
    ref.onDispose(() => _channel?.unsubscribe());

    // Subscribe before fetching so nothing can slip through the gap; the id
    // check in the callback absorbs any overlap.
    _subscribe();

    final rows = await rpcList('get_messages', params: {
      'p_deal_id': dealId,
      'p_limit': _pageSize,
    });
    _hasMore = rows.length == _pageSize;

    // The RPC returns newest-first so it can page with a `before` cursor;
    // the thread renders oldest-first.
    return rows.map(Message.fromJson).toList().reversed.toList();
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

  Future<void> send(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    await supabase.from('messages').insert({
      'deal_id': dealId,
      'sender_id': uid,
      // `body` is NOT NULL but had no length bound, so a paste could push an
      // arbitrarily large row through Realtime to the other device.
      'body': trimmed.length > 4000 ? trimmed.substring(0, 4000) : trimmed,
    });
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
