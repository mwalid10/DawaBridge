import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/l10n_extensions.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import 'news_article.dart';

class NewsDetailScreen extends StatelessWidget {
  const NewsDetailScreen({super.key, required this.articleId, this.article});

  final String articleId;
  final NewsArticle? article;

  Future<NewsArticle> _fetch() async {
    final row = await supabase.from('news_articles').select().eq('id', articleId).single();
    return NewsArticle.fromJson(row);
  }

  @override
  Widget build(BuildContext context) {
    if (article != null) return _NewsDetailBody(article: article!);
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<NewsArticle>(
        future: _fetch(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(child: Text(context.l10n.newsDetailCouldntLoad, style: Theme.of(context).textTheme.titleMedium));
            }
            return const Center(child: CircularProgressIndicator());
          }
          return _NewsDetailBody(article: snapshot.data!, embedded: true);
        },
      ),
    );
  }
}

class _NewsDetailBody extends StatelessWidget {
  const _NewsDetailBody({required this.article, this.embedded = false});

  final NewsArticle article;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final body = ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (article.coverImageUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: CachedNetworkImage(
              imageUrl: article.coverImageUrl!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              memCacheWidth: (MediaQuery.sizeOf(context).width * 2).round(),
              memCacheHeight: 360,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
          child: Text(
            article.category.label(l10n),
            style: textTheme.labelSmall?.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(article.title, style: textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          [if (article.source != null) article.source!, DateFormat.yMMMd().format(article.publishedAt)].join(' · '),
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(article.body, style: textTheme.bodyLarge),
      ],
    );

    if (embedded) return body;
    return Scaffold(appBar: AppBar(title: Text(l10n.newsTitle)), body: body);
  }
}
