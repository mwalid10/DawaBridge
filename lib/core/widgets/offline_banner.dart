import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../connectivity.dart';
import '../l10n_extensions.dart';
import '../theme.dart';

/// The app-wide "no connection" strip.
///
/// Wraps the whole router output (see `main.dart`) rather than being added
/// per-screen, because "why did that fail?" is a question that can be asked
/// from any screen. Before this, a request that failed for want of a network
/// looked exactly like one the server rejected — the user had no way to tell
/// "you're offline" from "that isn't allowed".
///
/// Deliberately a banner, not a blocking overlay: browsing cached listings,
/// reading a chat thread, typing a reply and getting to Account settings all
/// still work offline, and covering the screen would take that away for no
/// gain.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ListenableBuilder(
            listenable: connectivityController,
            builder: (context, _) {
              final offline = connectivityController.isOffline;
              return AnimatedSlide(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                offset: offline ? Offset.zero : const Offset(0, -1),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 260),
                  opacity: offline ? 1 : 0,
                  // IgnorePointer so the hidden banner can't swallow taps
                  // meant for the app bar underneath it.
                  child: IgnorePointer(
                    ignoring: !offline,
                    child: offline ? const _BannerBody() : const SizedBox.shrink(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF8A4B00), AppColors.warn],
          ),
          boxShadow: [
            BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // A slow pulse reads as "still trying" rather than "broken",
                // which is the honest state — the controller retries on its
                // own the moment an interface comes back.
                const Icon(Icons.cloud_off_rounded, size: 15, color: Colors.white)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fadeIn(duration: 900.ms)
                    .then()
                    .fade(end: 0.45, duration: 900.ms),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    l10n.offlineBanner,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().slideY(begin: -0.4, duration: 300.ms, curve: Curves.easeOutBack);
  }
}
