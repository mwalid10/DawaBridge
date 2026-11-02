import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity.dart';
import '../../core/l10n_extensions.dart';
import '../../core/widgets/gradient_fab.dart';
import '../add_medicine/add_medicine_screen.dart';
import '../chat/chat_list_screen.dart';
import '../deals/deals_controller.dart';
import '../news/news_screen.dart';
import '../notifications/notifications_controller.dart';
import '../profile/profile_screen.dart';
import '../push/push_token_controller.dart';
import '../search/search_screen.dart';
import 'app_nav_bar.dart';
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
      floatingActionButtonLocation: const AboveNavBarFabLocation(),
      bottomNavigationBar: AppNavBar(
        selectedIndex: _index,
        onSelect: _select,
        destinations: [
          AppNavDestination(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: l10n.navHome, index: 0),
          AppNavDestination(icon: Icons.search_rounded, selectedIcon: Icons.search_rounded, label: l10n.navSearch, index: 1),
          AppNavDestination(icon: Icons.chat_bubble_outline_rounded, selectedIcon: Icons.chat_bubble_rounded, label: l10n.navChat, index: 3),
          AppNavDestination(icon: Icons.newspaper_outlined, selectedIcon: Icons.newspaper_rounded, label: l10n.navNews, index: 4),
          AppNavDestination(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: l10n.navProfile, index: 5),
        ],
      ),
    );
  }

  void _select(int index) => setState(() {
        _index = index;
        _visited.add(index);
      });
}

