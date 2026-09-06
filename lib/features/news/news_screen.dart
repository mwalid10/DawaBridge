import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n_extensions.dart';
import '../../core/theme.dart';
import 'news_article.dart';
import 'news_controller.dart';
import 'widgets/news_card.dart';

class NewsScreen extends ConsumerWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articles = ref.watch(newsControllerProvider);
    final notifier = ref.watch(newsControllerProvider.notifier);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newsTitle)),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                _CategoryChip(label: l10n.newsAll, selected: notifier.category == null, onTap: () => notifier.setCategory(null)),
                for (final c in NewsCategory.values) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _CategoryChip(label: c.label(l10n), selected: notifier.category == c, onTap: () => notifier.setCategory(c)),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: articles.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.inkFaint),
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.newsCouldntLoad, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                          child: const Icon(Icons.newspaper_rounded, size: 32, color: AppColors.primary),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(l10n.newsEmptyCategory, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  );
                }
                final showFeatured = notifier.category == null;
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) {
                    final article = items[i];
                    if (i == 0 && showFeatured) {
                      return _FeaturedNewsCard(article: article, onTap: () => context.push('/news/${article.id}', extra: article));
                    }
                    return NewsCard(article: article, onTap: () => context.push('/news/${article.id}', extra: article));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.primarySoft,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? Colors.white : AppColors.primaryDark,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

/// A large image-forward card for the most recent article — reads as a
/// news app's "top story" rather than another row identical to the rest
/// of the list. Only shown on the unfiltered "All" tab.
class _FeaturedNewsCard extends StatelessWidget {
  const _FeaturedNewsCard({required this.article, required this.onTap});

  final NewsArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          height: 220,
          decoration: BoxDecoration(
            boxShadow: AppShadows.card,
            gradient: article.coverImageUrl == null ? AppGradients.hero : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (article.coverImageUrl != null)
                CachedNetworkImage(
                  imageUrl: article.coverImageUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: (MediaQuery.sizeOf(context).width * 2).round(),
                  memCacheHeight: 440,
                  errorWidget: (context, url, error) => const DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.hero)),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: 0.75)],
                    stops: const [0.35, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.pill)),
                      child: Text(
                        article.category.label(context.l10n),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(DateFormat.yMMMd().format(article.publishedAt), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
