import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n_extensions.dart';
import '../../core/locale_controller.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_hero_background.dart';
import '../../core/widgets/star_picker.dart';
import '../home/home_stats_controller.dart';
import 'profile_controller.dart';
import 'rating_summary.dart';

/// Pharmacy-facing profile: identity, ratings/reviews/statistics, Disputes.
/// Account settings (plan, sign out) live on a separate screen reached via
/// the gear icon — see AccountSettingsScreen.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(pharmacyProfileControllerProvider);
    final ratings = ref.watch(ratingSummaryControllerProvider);
    final stats = ref.watch(homeStatsControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(pharmacyProfileControllerProvider.notifier).refresh();
          await ref.read(ratingSummaryControllerProvider.notifier).refresh();
          ref.invalidate(homeStatsControllerProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            GradientHeroBackground(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 56),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.profileTitle, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white)),
                      IconButton(
                        tooltip: l10n.profileAccountSettingsTooltip,
                        icon: const Icon(Icons.settings_rounded, color: Colors.white),
                        onPressed: () => context.push('/profile/account'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -44),
              child: Column(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      gradient: AppGradients.hero,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.card,
                    ),
                    child: const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.storefront_rounded, color: AppColors.primary, size: 34),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  profile.when(
                    loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: CircularProgressIndicator()),
                    error: (error, _) => Text(l10n.profileCouldntLoad, style: Theme.of(context).textTheme.bodyMedium),
                    data: (pharmacy) => Column(
                      children: [
                        Text(pharmacy.name, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                        const SizedBox(height: 2),
                        Text(
                          '${pharmacy.email} · ${pharmacy.governorate}, ${pharmacy.area}',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.star_rounded,
                            value: ratings.maybeWhen(data: (s) => s.avgStars?.toStringAsFixed(1) ?? '—', orElse: () => '—'),
                            label: l10n.profileStatRating,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.swap_horiz_rounded,
                            value: stats.maybeWhen(data: (s) => '${s.completedExchanges}', orElse: () => '—'),
                            label: l10n.profileStatExchanges,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.inventory_2_rounded,
                            value: stats.maybeWhen(data: (s) => '${s.activeListings}', orElse: () => '—'),
                            label: l10n.profileStatActive,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: ratings.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (summary) => _RatingCard(summary: summary),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: GlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ListTile(
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
                            ),
                            leading: const Icon(Icons.inventory_2_rounded, color: AppColors.inkSoft),
                            title: Text(l10n.profileMyListings),
                            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                            onTap: () => context.push('/my-listings'),
                          ),
                          const Divider(height: 1, indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                          ListTile(
                            leading: const Icon(Icons.favorite_rounded, color: AppColors.inkSoft),
                            title: Text(l10n.profileMyFavorites),
                            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                            onTap: () => context.push('/favorites'),
                          ),
                          const Divider(height: 1, indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                          ListTile(
                            leading: const Icon(Icons.flag_rounded, color: AppColors.inkSoft),
                            title: Text(l10n.profileDisputes),
                            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                            onTap: () => context.push('/disputes'),
                          ),
                          const Divider(height: 1, indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.language_rounded, color: AppColors.inkSoft, size: 22),
                                    const SizedBox(width: 16),
                                    Text(l10n.profileLanguage, style: Theme.of(context).textTheme.bodyLarge),
                                  ],
                                ),
                                const _LanguageSwitcher(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two-way English/Arabic toggle — persisted via [localeControllerProvider]
/// (shared_preferences), read by MaterialApp.router at the top of the tree
/// so switching here relocalizes every screen immediately.
class _LanguageSwitcher extends ConsumerWidget {
  const _LanguageSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeControllerProvider);
    return SegmentedButton<String>(
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        selectedBackgroundColor: AppColors.primarySoft,
        selectedForegroundColor: AppColors.primaryDark,
      ),
      segments: [
        ButtonSegment(value: 'en', label: Text(l10n.languageEnglish)),
        ButtonSegment(value: 'ar', label: Text(l10n.languageArabic)),
      ],
      selected: {locale.languageCode},
      onSelectionChanged: (selection) => ref.read(localeControllerProvider.notifier).setLocale(Locale(selection.first)),
    );
  }
}

/// Compact stat card for the rating/exchanges/active-listings row — same
/// data source as the Home header stats, restyled for a plain (non-hero)
/// background.
class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.summary});

  final RatingSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;
    if (summary.count == 0 || summary.avgStars == null) {
      return GlassCard(
        child: Row(
          children: [
            const Icon(Icons.star_border_rounded, color: AppColors.inkFaint, size: 24),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                l10n.profileNoRatingsYet,
                style: textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.profileRatingsReviews, style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              StarDisplay(value: summary.avgStars!),
              const SizedBox(width: AppSpacing.sm),
              Text(summary.avgStars!.toStringAsFixed(1), style: textTheme.titleMedium),
              const SizedBox(width: AppSpacing.xs),
              Text(l10n.profileRatingCount(summary.count), style: textTheme.bodySmall),
            ],
          ),
          if (summary.avgCredibility != null || summary.avgResponsiveness != null || summary.avgPackaging != null) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),
            _SubMetricRow(label: l10n.profileCredibility, value: summary.avgCredibility),
            _SubMetricRow(label: l10n.profileResponsiveness, value: summary.avgResponsiveness),
            _SubMetricRow(label: l10n.profilePackaging, value: summary.avgPackaging),
          ],
        ],
      ),
    );
  }
}

class _SubMetricRow extends StatelessWidget {
  const _SubMetricRow({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text(value!.toStringAsFixed(1), style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
