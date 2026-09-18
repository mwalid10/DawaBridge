import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Rows from a previous successful fetch, with the time they were taken.
class CachedRows {
  const CachedRows(this.rows, this.cachedAt);

  final List<Map<String, dynamic>> rows;
  final DateTime cachedAt;

  /// Old enough that the UI should say so. Not an expiry — stale data still
  /// beats an empty screen when there's no way to get fresh data.
  bool get isStale => DateTime.now().difference(cachedAt) > const Duration(hours: 6);
}

/// Read-through cache so the marketplace is still browsable with no signal.
///
/// Stores the **raw rows the RPC returned**, not parsed models. That's
/// deliberate: a `toJson` written by hand alongside each `fromJson` is a
/// second parser that has to be kept in step with the first, and the moment
/// they drift the cache starts handing back subtly wrong objects. Caching
/// the wire format means `fromJson` stays the only parser in the app.
///
/// Backed by shared_preferences rather than sqflite/hive — the working set
/// here is a few hundred rows, and adding a database (plus its native build
/// config on two platforms) to store that would be the wrong trade.
class OfflineCache {
  OfflineCache._();

  static const _prefix = 'cache_v1_';

  /// Guards against a pathological feed filling the user's prefs store.
  /// Roughly 500 KB of JSON at the sizes these rows actually are.
  static const _maxRowsPerKey = 200;

  // Keys. Anything keyed per-entity includes the id so two listings can't
  // overwrite each other.
  static const feed = 'feed';
  static const myListings = 'my_listings';
  static const favorites = 'favorites';
  static const deals = 'deals';
  static String listing(String id) => 'listing_$id';
  static String messages(String dealId) => 'messages_$dealId';

  static Future<void> write(String key, List<Map<String, dynamic>> rows) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final capped = rows.length > _maxRowsPerKey ? rows.sublist(0, _maxRowsPerKey) : rows;
      await prefs.setString(
        '$_prefix$key',
        jsonEncode({'at': DateTime.now().toIso8601String(), 'rows': capped}),
      );
    } catch (error) {
      // A cache write failing is never worth surfacing — the live data the
      // user is looking at arrived fine.
      debugPrint('OfflineCache.write($key) failed: $error');
    }
  }

  static Future<CachedRows?> read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw == null) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.tryParse(decoded['at'] as String? ?? '');
      final rows = (decoded['rows'] as List<dynamic>?) ?? const [];
      if (at == null) return null;

      return CachedRows(
        rows.cast<Map<String, dynamic>>().toList(),
        at,
      );
    } catch (error) {
      debugPrint('OfflineCache.read($key) failed: $error');
      return null;
    }
  }

  /// Wipes everything cached. Called on sign-out — one pharmacy's feed,
  /// listings and chat threads must not be readable by whoever signs in on
  /// the same device next.
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (error) {
      debugPrint('OfflineCache.clear failed: $error');
    }
  }
}
