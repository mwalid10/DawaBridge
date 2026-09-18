import 'package:flutter/material.dart';

import '../app_error.dart';
import '../connectivity.dart';
import '../l10n_extensions.dart';
import '../theme.dart';

/// The standard "that didn't load" state.
///
/// Six screens previously rendered an error with no way to recover from it —
/// the profile tab, edit profile, account settings, news, the chat thread and
/// the listing editor. On a flaky connection that meant the only way out was
/// to kill the app, because nothing else on those screens triggered a
/// refetch.
///
/// It also tells the two cases apart. "You're offline" and "the server said
/// no" want different words and different expectations, and the app used to
/// show one message for both.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({
    super.key,
    required this.error,
    required this.onRetry,
    this.compact = false,
  });

  final Object error;
  final VoidCallback onRetry;

  /// Tighter layout for inline use inside an already-populated screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final offline = ConnectivityController.looksOffline(error) || connectivityController.isOffline;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
              size: compact ? 32 : 40,
              color: AppColors.inkFaint,
            ),
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
            Text(
              AppError.message(l10n, error),
              textAlign: TextAlign.center,
              style: compact
                  ? Theme.of(context).textTheme.bodyMedium
                  : Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
            // Reconnection retries these automatically (see the
            // `onReconnected` listeners in the controllers), but an explicit
            // button matters for the captive-portal case where the interface
            // never dropped and so no reconnect event ever fires.
            ElevatedButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}
