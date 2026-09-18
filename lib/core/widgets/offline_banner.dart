import 'package:flutter/material.dart';

import '../connectivity.dart';
import '../l10n_extensions.dart';
import '../theme.dart';

/// A thin strip across the top of the app whenever the backend is
/// unreachable.
///
/// Wraps the whole router output (see `main.dart`) rather than being added
/// per-screen, because "why did that fail?" is a question that can be asked
/// from any screen. Before this, a request that failed for want of a network
/// looked exactly like one the server rejected — the user had no way to tell
/// "you're offline" from "that isn't allowed".
///
/// Deliberately a banner, not a blocking overlay: browsing already-loaded
/// listings, reading a chat thread and getting to Account settings all still
/// work offline, and covering the screen would take that away for no gain.
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
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                offset: offline ? Offset.zero : const Offset(0, -1),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: offline ? 1 : 0,
                  // IgnorePointer so the hidden banner can't swallow taps
                  // meant for the app bar underneath it.
                  child: IgnorePointer(
                    ignoring: !offline,
                    child: const _BannerBody(),
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
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          color: AppColors.warn,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 14, color: Colors.white),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  l10n.offlineBanner,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
