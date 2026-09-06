import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import 'app_notification.dart';

/// The signed-in pharmacy's notifications, newest first, kept live via a
/// Realtime subscription (new rows only arrive here — deal_requested,
/// deal completed/cancelled, new_message — see the notify_new_message
/// trigger and request_listing/respond_to_deal RPCs in
/// 0007_deals_chat_notifications.sql).
class NotificationsController extends AsyncNotifier<List<AppNotification>> {
  RealtimeChannel? _channel;

  @override
  Future<List<AppNotification>> build() async {
    ref.onDispose(() => _channel?.unsubscribe());

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return const [];

    final rows = await supabase.from('notifications').select().eq('pharmacy_id', uid).order('created_at', ascending: false);
    _subscribe(uid);
    return (rows as List<dynamic>).map((row) => AppNotification.fromJson(row as Map<String, dynamic>)).toList();
  }

  void _subscribe(String uid) {
    _channel = supabase
        .channel('notifications-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'pharmacy_id', value: uid),
          callback: (payload) {
            final notification = AppNotification.fromJson(payload.newRecord);
            final current = state.value ?? [];
            if (current.any((n) => n.id == notification.id)) return;
            state = AsyncValue.data([notification, ...current]);
          },
        )
        .subscribe();
  }

  Future<void> markRead(String id) async {
    final current = state.value ?? [];
    final index = current.indexWhere((n) => n.id == id);
    if (index == -1 || current[index].read) return;

    final updated = [...current];
    updated[index] = updated[index].copyWith(read: true);
    state = AsyncValue.data(updated);

    await supabase.from('notifications').update({'read': true}).eq('id', id);
  }

  /// Optimistic remove (same shape as markRead's optimistic update) with
  /// rollback on failure — backs the notifications list's swipe-to-delete.
  Future<void> delete(String id) async {
    final current = state.value ?? [];
    final removed = current.where((n) => n.id == id).toList();
    if (removed.isEmpty) return;

    state = AsyncValue.data(current.where((n) => n.id != id).toList());

    try {
      await supabase.from('notifications').delete().eq('id', id);
    } catch (_) {
      state = AsyncValue.data(current);
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}

final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, List<AppNotification>>(NotificationsController.new);

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsControllerProvider).value;
  return notifications?.where((n) => !n.read).length ?? 0;
});
