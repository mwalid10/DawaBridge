import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n_extensions.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../news_article.dart';

class NewsCard extends StatelessWidget {
  const NewsCard({super.key, required this.article, required this.onTap});

  final NewsArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.coverImageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: CachedNetworkImage(
                  imageUrl: article.coverImageUrl!,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  memCacheWidth: 128,
                  memCacheHeight: 128,
                  errorWidget: (context, url, error) => Container(
                    width: 64,
                    height: 64,
                    color: AppColors.primarySoft,
                    child: const Icon(Icons.newspaper_rounded, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
                    child: Text(
                      article.category.label(context.l10n),
                      style: textTheme.labelSmall?.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(article.title, style: textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(article.summary, style: textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.xs),
                  Text(DateFormat.yMMMd().format(article.publishedAt), style: textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
