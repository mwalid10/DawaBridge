import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import 'news_article.dart';

/// News feed, optionally filtered by category — same
/// AsyncNotifier-with-mutable-filter shape as SearchController, minus
/// pagination since the feed is small.
class NewsController extends AsyncNotifier<List<NewsArticle>> {
  NewsCategory? category;

  @override
  Future<List<NewsArticle>> build() => _fetch();

  Future<List<NewsArticle>> _fetch() async {
    var query = supabase.from('news_articles').select();
    if (category != null) {
      query = query.eq('category', category!.dbValue);
    }
    final rows = await query.order('published_at', ascending: false);
    return (rows as List<dynamic>).map((row) => NewsArticle.fromJson(row as Map<String, dynamic>)).toList();
  }

  Future<void> setCategory(NewsCategory? newCategory) async {
    category = newCategory;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }
}

final newsControllerProvider = AsyncNotifierProvider<NewsController, List<NewsArticle>>(NewsController.new);
