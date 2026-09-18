import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n_extensions.dart';
import '../../core/session.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/status_pill.dart';

/// The holding screen for any signed-in account that isn't an approved
/// pharmacy: awaiting KYC review, rejected, suspended, or an admin account
/// signed into the pharmacy app.
///
/// Replaces the old `PendingApprovalScreen`, which only ever appeared as
/// the last step of the registration wizard. Because nothing else in the
/// app looked at `pharmacies.status`, signing out and back in walked
/// straight past it into the full marketplace — the KYC gate was purely
/// decorative. The router now sends every non-approved session here (see
/// `core/router.dart`), and migration 0034 enforces the same rule in RLS.
///
/// Keeps the realtime subscription so an admin's approval flips the screen
/// live, but it now refreshes the session controller rather than navigating
/// by hand — the router redirect owns where the user goes next.
class AccountStatusScreen extends ConsumerStatefulWidget {
  const AccountStatusScreen({super.key});

  @override
  ConsumerState<AccountStatusScreen> createState() => _AccountStatusScreenState();
}

class _AccountStatusScreenState extends ConsumerState<AccountStatusScreen> {
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    _channel = supabase
        .channel('pharmacy-status-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'pharmacies',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: userId),
          callback: (_) => sessionController.refresh(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ListenableBuilder(
      listenable: sessionController,
      builder: (context, _) {
        final state = sessionController.state;

        final (icon, pillKind, pillLabel, title, body, isBad) = switch (state) {
          SessionState.rejected => (
              Icons.cancel_outlined,
              StatusPillKind.rejected,
              l10n.kycRejectedLabel,
              l10n.kycApplicationRejected,
              l10n.kycRejectedBody,
              true,
            ),
          SessionState.suspended => (
              Icons.gpp_bad_outlined,
              StatusPillKind.rejected,
              l10n.kycSuspendedLabel,
              l10n.kycAccountSuspended,
              l10n.kycSuspendedBody,
              true,
            ),
          SessionState.admin => (
              Icons.admin_panel_settings_outlined,
              StatusPillKind.pending,
              l10n.kycAdminLabel,
              l10n.kycAdminTitle,
              l10n.kycAdminBody,
              false,
            ),
          _ => (
              Icons.hourglass_top_rounded,
              StatusPillKind.pending,
              l10n.kycPendingReview,
              l10n.kycVerificationInProgress,
              l10n.kycPendingBody,
              false,
            ),
        };

        final badgeColor = isBad ? AppColors.danger : AppColors.primary;
        final badgeBg = isBad ? AppColors.dangerBg : AppColors.primarySoft;

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
                    child: Icon(icon, size: 56, color: badgeColor),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  StatusPill(kind: pillKind, label: pillLabel),
                  const SizedBox(height: AppSpacing.md),
                  Text(title, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.sm),
                  Text(body, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                  const Spacer(),
                  // Without a way off this screen the only escape was
                  // reinstalling the app — and App Store review requires an
                  // account-deletion path that stays reachable.
                  TextButton(
                    onPressed: () => context.push('/profile/account'),
                    child: Text(l10n.accountSettingsTitle),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
