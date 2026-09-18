import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/notifications_controller.dart';
import '../theme.dart';

/// Bell icon with an unread-count badge, navigating to /notifications.
/// Drop into an AppBar's `actions`.
class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The count is a server-side `count(*)` now rather than the length of a
    // client-side list, so it's async — and correct without having to
    // download every notification row first.
    final unread = ref.watch(unreadNotificationsCountProvider).value ?? 0;

    return IconButton(
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        backgroundColor: AppColors.danger,
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
