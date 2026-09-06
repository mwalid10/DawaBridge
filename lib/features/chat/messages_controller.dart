import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import 'message.dart';

/// Messages for one deal's thread — fetched once, then kept live via a
/// Realtime subscription (same `onPostgresChanges` pattern as
/// pending_approval_screen.dart). Sending relies entirely on the
/// subscription echoing the insert back rather than an optimistic local
/// append, so there's a single source of truth for message order.
class MessagesController extends AsyncNotifier<List<Message>> {
  MessagesController(this.dealId);

  final String dealId;
  RealtimeChannel? _channel;

  @override
  Future<List<Message>> build() async {
    ref.onDispose(() => _channel?.unsubscribe());

    // postgrest's .order() defaults ascending to false — without this the
    // initial fetch comes back newest-first, which then conflicts with
    // _subscribe() appending new realtime messages to the end of the list.
    final rows = await supabase.from('messages').select().eq('deal_id', dealId).order('created_at', ascending: true);
    _subscribe();
    return (rows as List<dynamic>).map((row) => Message.fromJson(row as Map<String, dynamic>)).toList();
  }

  void _subscribe() {
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

  Future<void> send(String body) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('messages').insert({'deal_id': dealId, 'sender_id': uid, 'body': body});
  }

  /// Uploads [localPath] to the deal-scoped chat-attachments path
  /// (`<dealId>/<uid>-<timestamp>.<ext>` — matches the participant-scoped
  /// RLS from 0014_messages_attachments.sql) and posts a message carrying
  /// just the storage path, not a public URL, since the bucket stays
  /// private; readers resolve it to a signed URL on demand.
  Future<void> sendAttachment(String localPath) async {
    final uid = supabase.auth.currentUser!.id;
    final ext = localPath.split('.').last;
    final path = '$dealId/$uid-${DateTime.now().microsecondsSinceEpoch}.$ext';
    await supabase.storage.from('chat-attachments').upload(path, File(localPath));
    await supabase.from('messages').insert({
      'deal_id': dealId,
      'sender_id': uid,
      'body': '📎 Attachment',
      'attachment_path': path,
    });
  }

  /// Posts the caller's current coordinates as a location-share message —
  /// rendered client-side as a small map preview (see _LocationPreview in
  /// chat_thread_screen.dart) rather than a generic attachment, so it needs
  /// its own columns instead of going through attachment_path.
  Future<void> sendLocation({required double lat, required double lng}) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('messages').insert({
      'deal_id': dealId,
      'sender_id': uid,
      'body': '📍 Shared location',
      'location_lat': lat,
      'location_lng': lng,
    });
  }
}

final messagesControllerProvider =
    AsyncNotifierProvider.autoDispose.family<MessagesController, List<Message>, String>(
  (id) => MessagesController(id),
);
