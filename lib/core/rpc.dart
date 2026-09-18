import 'dart:async';

import 'connectivity.dart';
import 'offline_cache.dart';
import 'supabase_client.dart';

/// Thrown when a single-row RPC legitimately comes back with no row.
///
/// The controllers all did `(rows as List).first`, which throws a bare
/// `StateError: No element` — surfacing as a red error screen with no
/// explanation. That wasn't a theoretical edge case:
///
///   * `get_listing_detail` only returns a row when the listing is
///     available *or* owned by the caller. Favourites deliberately keeps
///     listings of every state, so opening a saved listing that the seller
///     has since completed hit exactly this.
///   * The same applies to a notification deep link pointing at a listing
///     or deal that has since closed.
///
/// Callers catch this and show "no longer available" instead of crashing.
class NotFoundException implements Exception {
  const NotFoundException(this.what);
  final String what;

  @override
  String toString() => 'NotFoundException: $what';
}

/// Every network read goes through here.
///
/// Two jobs, both of which the app was missing:
///
///   * **A timeout.** Supabase's client has no default deadline, so on a
///     dead connection a request sits until the platform socket gives up —
///     minutes, during which the screen shows a spinner and the user has no
///     idea anything is wrong.
///   * **Feeding the connectivity signal.** `ConnectivityController` treats
///     real request outcomes as ground truth for whether we're online,
///     because the OS-level "is there an interface" reading says yes on a
///     captive-portal wifi or a mobile connection with no data left.
Future<T> guardNetwork<T>(
  Future<T> Function() request, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  try {
    final result = await request().timeout(timeout);
    connectivityController.reportSuccess();
    return result;
  } catch (error) {
    if (ConnectivityController.looksOffline(error)) {
      connectivityController.reportFailure();
    }
    rethrow;
  }
}

/// Calls an RPC expected to return exactly one row.
Future<Map<String, dynamic>> rpcSingle(
  String function, {
  Map<String, dynamic>? params,
  required String notFoundLabel,
}) async {
  final rows = await guardNetwork(() => supabase.rpc(function, params: params));
  final list = (rows as List<dynamic>?) ?? const [];
  if (list.isEmpty) throw NotFoundException(notFoundLabel);
  return list.first as Map<String, dynamic>;
}

/// Calls an RPC returning zero or more rows.
///
/// Pass [cacheKey] to make the call read-through: rows are cached on every
/// success, and a network failure falls back to the last good copy instead
/// of an error screen. Only use it for reads whose result is the same for
/// every call — a filtered search must not be cached under a key that an
/// unfiltered one would also read.
Future<List<Map<String, dynamic>>> rpcList(
  String function, {
  Map<String, dynamic>? params,
  String? cacheKey,
}) async {
  try {
    final rows = await guardNetwork(() => supabase.rpc(function, params: params));
    final list = ((rows as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>()
        .toList();
    if (cacheKey != null) unawaited(OfflineCache.write(cacheKey, list));
    return list;
  } catch (error) {
    if (cacheKey == null || !ConnectivityController.looksOffline(error)) rethrow;
    // Offline with something cached: show it. A stale listing the user can
    // read and act on when they reconnect is worth more than an error.
    final cached = await OfflineCache.read(cacheKey);
    if (cached == null) rethrow;
    return cached.rows;
  }
}

/// Single-row variant of [rpcList]'s cache behaviour.
Future<Map<String, dynamic>> rpcSingleCached(
  String function, {
  Map<String, dynamic>? params,
  required String cacheKey,
  required String notFoundLabel,
}) async {
  final rows = await rpcList(function, params: params, cacheKey: cacheKey);
  if (rows.isEmpty) throw NotFoundException(notFoundLabel);
  return rows.first;
}
