import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_error.dart';
import '../../core/l10n_extensions.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_card.dart';
import '../push/push_token_controller.dart';
import 'pharmacy_profile.dart';
import 'profile_controller.dart';

/// Account settings ("User Profile" in the Figma spec) — plan/trial status
/// and sign out, split out of the pharmacy-facing ProfileScreen so that
/// screen stays focused on identity/ratings.
class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(pharmacyProfileControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          profile.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: CircularProgressIndicator())),
            error: (error, _) => Center(
              child: Text(l10n.accountCouldntLoad, style: Theme.of(context).textTheme.bodyMedium),
            ),
            data: (pharmacy) => _PlanCard(pharmacy: pharmacy),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
              leading: const Icon(Icons.edit_rounded, color: AppColors.inkSoft),
              title: Text(l10n.accountEditProfile),
              subtitle: Text(l10n.accountEditProfileSubtitle),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () => context.push('/profile/edit'),
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger, width: 1.5),
            ),
            onPressed: () => _signOut(context),
            child: Text(l10n.accountSignOut),
          ),
          const SizedBox(height: AppSpacing.xxl),
          // Required by App Store Guideline 5.1.1(v) and Google Play for any
          // app that lets users create an account. There was no deletion
          // path at all, in-app or otherwise, which on its own would have
          // blocked the iOS release.
          _DeleteAccountButton(),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.accountDeleteExplainer,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    // Drop this device's push token *before* the session goes away — the
    // RLS policy on device_push_tokens is owner-scoped, so afterwards the
    // delete would be silently refused. Without this the row survived and
    // the handset kept receiving pushes for the account that just logged
    // out, including message notifications from its deals.
    await unregisterPushToken();
    await supabase.auth.signOut();
    // No manual navigation: the session controller picks up signedOut and
    // the router redirect moves us.
  }
}

class _DeleteAccountButton extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DeleteAccountButton> createState() => _DeleteAccountButtonState();
}

class _DeleteAccountButtonState extends ConsumerState<_DeleteAccountButton> {
  bool _deleting = false;

  Future<void> _confirmAndDelete() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.accountDeleteTitle),
        content: Text(l10n.accountDeleteWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.accountDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await unregisterPushToken();
      await supabase.rpc('delete_my_account');
      await supabase.auth.signOut();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountDeleteDone)));
    } catch (error) {
      if (!mounted) return;
      // Deletion is refused while a deal or dispute is still open, so the
      // other party's transaction isn't left dangling — the message has to
      // say which, not show a raw Postgres error.
      messenger.showSnackBar(SnackBar(content: Text(AppError.message(l10n, error))));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextButton.icon(
      onPressed: _deleting ? null : _confirmAndDelete,
      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
      icon: _deleting
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.danger),
            )
          : const Icon(Icons.delete_forever_rounded, size: 20),
      label: Text(l10n.accountDelete),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.pharmacy});

  final PharmacyProfile pharmacy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    // `.inDays` truncates toward zero, so 23 hours remaining read as
    // "0 days left" while `daysLeft < 0` still said the trial was live —
    // the whole final day showed a countdown of zero. Round up instead, and
    // treat "the end date has passed" as the expiry test.
    final trialEnds = pharmacy.trialEndsAt;
    final remaining = trialEnds?.difference(DateTime.now());
    final trialExpired = pharmacy.plan == PlanStatus.trial && remaining != null && remaining.isNegative;
    final daysLeft = remaining == null ? null : (remaining.inMinutes / (60 * 24)).ceil();

    final (fg, bg) = switch (pharmacy.plan) {
      PlanStatus.active => (AppColors.good, AppColors.goodBg),
      PlanStatus.trial => trialExpired ? (AppColors.danger, AppColors.dangerBg) : (AppColors.warn, AppColors.warnBg),
      PlanStatus.free => (AppColors.inkSoft, AppColors.background),
    };

    return GlassCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(Icons.workspace_premium_rounded, color: fg, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(l10n.accountPlanSuffix(pharmacy.plan.label(l10n)), style: textTheme.titleMedium),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
                      child: Text(
                        pharmacy.plan.label(l10n),
                        style: textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  pharmacy.plan != PlanStatus.trial || daysLeft == null
                      ? l10n.accountNoTrialCountdown
                      : trialExpired
                          ? l10n.accountTrialEnded
                          : l10n.accountTrialDaysLeft(daysLeft),
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
