import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n_extensions.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_card.dart';
import 'app_notification.dart';
import 'notifications_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _iconFor(String kind) => switch (kind) {
        'new_message' => Icons.chat_bubble_outline_rounded,
        _ => Icons.notifications_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsTitle)),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.inkFaint),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.notificationsCouldntLoad, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () => ref.read(notificationsControllerProvider.notifier).refresh(),
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.notifications_none, size: 40, color: AppColors.inkFaint),
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.notificationsEmpty, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(notificationsControllerProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) {
                final notification = items[i];
                return Dismissible(
                  key: ValueKey(notification.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(AppRadius.xl)),
                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  ),
                  onDismissed: (_) async {
                    try {
                      await ref.read(notificationsControllerProvider.notifier).delete(notification.id);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.l10n.notificationsDeleteError)),
                        );
                      }
                    }
                  },
                  child: _NotificationTile(
                    notification: notification,
                    icon: _iconFor(notification.kind),
                    onTap: () {
                      ref.read(notificationsControllerProvider.notifier).markRead(notification.id);
                      if (notification.dealId != null) {
                        context.push('/chat/${notification.dealId}');
                      } else if (notification.listingId != null) {
                        context.push('/listing/${notification.listingId}');
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.icon, required this.onTap});

  final AppNotification notification;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: notification.read ? AppColors.background : AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: notification.read ? AppColors.inkFaint : AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: textTheme.titleMedium?.copyWith(fontWeight: notification.read ? FontWeight.w500 : FontWeight.w700),
                  ),
                  if (notification.body != null) ...[
                    const SizedBox(height: 2),
                    Text(notification.body!, maxLines: 2, overflow: TextOverflow.ellipsis, style: textTheme.bodyMedium),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text(DateFormat.MMMd().add_jm().format(notification.createdAt), style: textTheme.bodySmall),
                ],
              ),
            ),
            if (!notification.read)
              Container(
                margin: const EdgeInsets.only(left: AppSpacing.sm, top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
