import '../../l10n/app_localizations.dart';

enum NewsCategory {
  regulatory,
  marketPricing,
  companyNews,
  recallsSafety,
  industryEvents,
  education;

  static NewsCategory fromString(String value) => switch (value) {
        'regulatory' => NewsCategory.regulatory,
        'market_pricing' => NewsCategory.marketPricing,
        'company_news' => NewsCategory.companyNews,
        'recalls_safety' => NewsCategory.recallsSafety,
        'industry_events' => NewsCategory.industryEvents,
        'education' => NewsCategory.education,
        _ => throw ArgumentError('Unknown news category: $value'),
      };

  String get dbValue => switch (this) {
        NewsCategory.regulatory => 'regulatory',
        NewsCategory.marketPricing => 'market_pricing',
        NewsCategory.companyNews => 'company_news',
        NewsCategory.recallsSafety => 'recalls_safety',
        NewsCategory.industryEvents => 'industry_events',
        NewsCategory.education => 'education',
      };

  String label(AppLocalizations l10n) => switch (this) {
        NewsCategory.regulatory => l10n.newsCategoryRegulatory,
        NewsCategory.marketPricing => l10n.newsCategoryMarketPricing,
        NewsCategory.companyNews => l10n.newsCategoryCompanyNews,
        NewsCategory.recallsSafety => l10n.newsCategoryRecallsSafety,
        NewsCategory.industryEvents => l10n.newsCategoryIndustryEvents,
        NewsCategory.education => l10n.newsCategoryEducation,
      };
}

/// Reference content row from `news_articles` — public read-only table.
class NewsArticle {
  final String id;
  final NewsCategory category;
  final String title;
  final String summary;
  final String body;
  final String? coverImageUrl;
  final String? source;
  final DateTime publishedAt;

  const NewsArticle({
    required this.id,
    required this.category,
    required this.title,
    required this.summary,
    required this.body,
    required this.coverImageUrl,
    required this.source,
    required this.publishedAt,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      id: json['id'] as String,
      category: NewsCategory.fromString(json['category'] as String),
      title: json['title'] as String,
      summary: json['summary'] as String,
      body: json['body'] as String,
      coverImageUrl: json['cover_image_url'] as String?,
      source: json['source'] as String?,
      publishedAt: DateTime.parse(json['published_at'] as String),
    );
  }
}
