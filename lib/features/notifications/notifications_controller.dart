import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import 'app_notification.dart';

/// The signed-in pharmacy's notifications, newest first, kept live via a
/// Realtime subscription.
///
/// Two things were wrong before:
///
///   * The initial fetch had no `.limit()` at all — it pulled every
///     notification row the pharmacy had ever received, on every app open.
///     Combined with the old `notify_new_message` trigger (one row per chat
///     message; fixed in migration 0035 to collapse per thread) an active
///     account would be downloading thousands of rows just to render a
///     badge number.
///   * The subscription was opened *after* the initial fetch awaited, so
///     anything inserted in that window was silently missed until the
///     screen was rebuilt.
class NotificationsController extends AsyncNotifier<List<AppNotification>> {
  static const _pageSize = 30;

  RealtimeChannel? _channel;
  bool _hasMore = true;
  bool _loadingMore = false;

  bool get hasMore => _hasMore;

  @override
  Future<List<AppNotification>> build() async {
    ref.onDispose(() => _channel?.unsubscribe());

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return const [];

    // Subscribe first, then fetch: an insert that lands mid-fetch is then
    // either already in the page we get back or arrives on the channel, and
    // the id check below de-duplicates the overlap. The other order loses
    // it entirely.
    _subscribe(uid);

    final rows = await supabase.rpc('get_notifications', params: {'p_limit': _pageSize});
    final page = ((rows as List<dynamic>?) ?? const [])
        .map((row) => AppNotification.fromJson(row as Map<String, dynamic>))
        .toList();
    _hasMore = page.length == _pageSize;
    return page;
  }

  void _subscribe(String uid) {
    _channel?.unsubscribe();
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
            ref.invalidate(unreadNotificationsCountProvider);
          },
        )
        .subscribe();
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final current = state.value ?? [];
    if (current.isEmpty) return;

    _loadingMore = true;
    try {
      final rows = await supabase.rpc('get_notifications', params: {
        'p_limit': _pageSize,
        'p_before': current.last.createdAt.toIso8601String(),
      });
      final page = ((rows as List<dynamic>?) ?? const [])
          .map((row) => AppNotification.fromJson(row as Map<String, dynamic>))
          .toList();
      _hasMore = page.length == _pageSize;

      final seen = current.map((n) => n.id).toSet();
      state = AsyncValue.data([...current, ...page.where((n) => !seen.contains(n.id))]);
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> markRead(String id) async {
    final current = state.value ?? [];
    final index = current.indexWhere((n) => n.id == id);
    if (index == -1 || current[index].read) return;

    final updated = [...current];
    updated[index] = updated[index].copyWith(read: true);
    state = AsyncValue.data(updated);

    try {
      await supabase.from('notifications').update({'read': true}).eq('id', id);
      ref.invalidate(unreadNotificationsCountProvider);
    } catch (_) {
      // The optimistic update had no rollback, unlike delete() right below
      // it — so a failed write left the row looking read forever while the
      // server still had it unread, and the badge disagreed with the list.
      state = AsyncValue.data(current);
      rethrow;
    }
  }

  /// There was no way to clear a backlog other than swiping every row.
  Future<void> markAllRead() async {
    final current = state.value ?? [];
    if (current.every((n) => n.read)) return;

    state = AsyncValue.data([for (final n in current) n.read ? n : n.copyWith(read: true)]);
    try {
      await supabase.rpc('mark_all_notifications_read');
      ref.invalidate(unreadNotificationsCountProvider);
    } catch (_) {
      state = AsyncValue.data(current);
      rethrow;
    }
  }

  /// Optimistic remove with rollback on failure — backs swipe-to-delete.
  Future<void> delete(String id) async {
    final current = state.value ?? [];
    final removed = current.where((n) => n.id == id).toList();
    if (removed.isEmpty) return;

    state = AsyncValue.data(current.where((n) => n.id != id).toList());

    try {
      await supabase.from('notifications').delete().eq('id', id);
      ref.invalidate(unreadNotificationsCountProvider);
    } catch (_) {
      state = AsyncValue.data(current);
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
    ref.invalidate(unreadNotificationsCountProvider);
  }
}

final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, List<AppNotification>>(NotificationsController.new);

/// Unread badge count.
///
/// Was computed in Dart by counting the (unbounded) notifications list,
/// which meant the badge couldn't be right unless the whole table had been
/// downloaded first. It's a single `count(*)` on the server now, so the
/// list can page without the badge lying.
final unreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  if (supabase.auth.currentUser == null) return 0;
  final result = await supabase.rpc('get_unread_notification_count');
  return (result as num?)?.toInt() ?? 0;
});
