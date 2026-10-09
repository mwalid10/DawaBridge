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
///
/// It takes its own space instead of floating over the app. As a `Positioned`
/// child of a `Stack` it painted on top of the status bar *and* the top of
/// whatever AppBar was underneath — going offline in a chat thread buried the
/// back button and sliced the title in half, so the screen looked broken and
/// the way out of it was invisible. A strip that pushes can't swallow a
/// control the way one that floats does.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    // Start settled, not animating: a cold start with no signal should show
    // the strip already in place rather than sliding it in over the splash.
    value: connectivityController.isOffline ? 1 : 0,
  );

  late final CurvedAnimation _reveal = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void initState() {
    super.initState();
    connectivityController.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    if (connectivityController.isOffline) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    connectivityController.removeListener(_onConnectivityChanged);
    _reveal.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return AnimatedBuilder(
      animation: _reveal,
      // Handed through as `child` so the router output is reparented on each
      // frame of the reveal rather than rebuilt.
      child: widget.child,
      builder: (context, child) {
        final t = _reveal.value;
        return Column(
          children: [
            if (t > 0)
              // Revealed from its bottom edge, so the strip reads as sliding
              // out from under the top of the screen.
              ClipRect(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  heightFactor: t,
                  child: const _BannerBody(),
                ),
              ),
            Expanded(
              // The strip carries the status bar inset itself (the SafeArea
              // in _BannerBody), so the app underneath must not add it a
              // second time — that would leave a band of dead app-bar colour
              // between the strip and the title. Scaled by the reveal so the
              // app slides down by exactly the strip's own height and neither
              // end of the animation jumps.
              child: MediaQuery(
                data: media.copyWith(
                  padding: media.padding.copyWith(top: media.padding.top * (1 - t)),
                  viewPadding: media.viewPadding.copyWith(top: media.viewPadding.top * (1 - t)),
                ),
                child: child!,
              ),
            ),
          ],
        );
      },
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
    );
  }
}
