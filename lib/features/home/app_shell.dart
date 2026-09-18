import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity.dart';
import '../../core/l10n_extensions.dart';
import '../../core/theme.dart';
import '../../core/widgets/gradient_fab.dart';
import '../add_medicine/add_medicine_screen.dart';
import '../chat/chat_list_screen.dart';
import '../deals/deals_controller.dart';
import '../news/news_screen.dart';
import '../notifications/notifications_controller.dart';
import '../profile/profile_screen.dart';
import '../push/push_token_controller.dart';
import '../search/search_screen.dart';
import 'home_feed_controller.dart';
import 'home_screen.dart';

/// Bottom-nav shell: Home / Search / (floating Add) / Chat / News / Profile.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;
  // IndexedStack builds every child up front regardless of which one is
  // visible — with all 6 tabs live from the moment Home first renders, that
  // meant Search/Add Medicine/Chat/News/Profile were all constructed (and
  // firing their own Riverpod-backed network fetches) immediately on
  // landing on Home, none of it visible yet. Only build a tab's real screen
  // once it's actually been selected at least once; unvisited tabs are a
  // cheap placeholder until then. Once built, IndexedStack still keeps it
  // alive/off-screen on switch, preserving scroll/form state as before.
  final Set<int> _visited = {0};

  List<Widget> get _tabs => [
        HomeScreen(onNavigateToTab: _select),
        const SearchScreen(),
        const AddMedicineScreen(),
        const ChatListScreen(),
        const NewsScreen(),
        const ProfileScreen(),
      ];

  StreamSubscription<void>? _reconnectSub;

  @override
  void initState() {
    super.initState();
    // Refetch whatever the app missed while it was offline. Realtime inserts
    // that happened while the socket was down are simply gone — the channel
    // reconnects but doesn't replay — so a refetch is the only way to catch
    // up, and without it a user who lost signal mid-session would keep
    // seeing a stale feed and an out-of-date chat list indefinitely.
    _reconnectSub = connectivityController.onReconnected.listen((_) {
      if (!mounted) return;
      ref.invalidate(homeFeedControllerProvider);
      ref.invalidate(dealsControllerProvider);
      ref.invalidate(notificationsControllerProvider);
      ref.invalidate(unreadNotificationsCountProvider);
    });
  }

  @override
  void dispose() {
    _reconnectSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(pushTokenControllerProvider);
    final l10n = context.l10n;
    final tabs = _tabs;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [for (var i = 0; i < tabs.length; i++) _visited.contains(i) ? tabs[i] : const SizedBox.shrink()],
      ),
      floatingActionButton: GradientFab(
        icon: Icons.add_rounded,
        onPressed: () => _select(2),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: AppColors.surface,
        padding: EdgeInsets.zero,
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // Two equal-width wings around a fixed-width FAB gap, rather
              // than spaceAround over 5 unevenly-grouped (2 vs 3) items —
              // spaceAround let the gap's position drift with label width
              // (English vs Arabic, "Search" vs "Chat", etc.), so it stopped
              // lining up with the truly-centered (centerDocked) FAB above.
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: l10n.navHome, index: 0, selected: _index == 0, onTap: _select),
                    _NavItem(icon: Icons.search_rounded, selectedIcon: Icons.search_rounded, label: l10n.navSearch, index: 1, selected: _index == 1, onTap: _select),
                  ],
                ),
              ),
              const SizedBox(width: 56),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _NavItem(icon: Icons.chat_bubble_outline_rounded, selectedIcon: Icons.chat_bubble_rounded, label: l10n.navChat, index: 3, selected: _index == 3, onTap: _select),
                    _NavItem(icon: Icons.newspaper_outlined, selectedIcon: Icons.newspaper_rounded, label: l10n.navNews, index: 4, selected: _index == 4, onTap: _select),
                    _NavItem(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: l10n.navProfile, index: 5, selected: _index == 5, onTap: _select),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _select(int index) => setState(() {
        _index = index;
        _visited.add(index);
      });
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int index;
  final bool selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.inkFaint;
    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
