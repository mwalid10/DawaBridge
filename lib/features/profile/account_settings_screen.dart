import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n_extensions.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_card.dart';
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
            onPressed: () async {
              await supabase.auth.signOut();
              if (context.mounted) context.go('/login');
            },
            child: Text(l10n.accountSignOut),
          ),
        ],
      ),
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
    final daysLeft = pharmacy.trialEndsAt?.difference(DateTime.now()).inDays;
    final trialExpired = pharmacy.plan == PlanStatus.trial && daysLeft != null && daysLeft < 0;

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
