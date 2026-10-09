import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../favorites/favorites_controller.dart';
import '../home/home_feed_controller.dart';
import '../home/home_stats_controller.dart';
import '../search/search_controller.dart';
import 'listing_detail_controller.dart';
import 'my_listings_controller.dart';

/// Refreshes every view that renders listings, as one unit.
///
/// One listing shows up in five separately cached places — the Home feed,
/// Search, My listings, Favourites and its own detail page — plus Home's
/// active-listings count. Each mutation site used to hand-pick a subset of
/// them, and each picked a different one: posting a medicine refreshed Home
/// and Search but not My listings, so the thing you just posted wasn't in
/// your list; saving an edit refreshed My listings but not Home or Search;
/// deleting refreshed only My listings, leaving the deleted row on the feed,
/// in search results and in other pharmacies' favourites. Whichever list you
/// opened next was the stale one — which is what "I have to refresh a few
/// times" actually was.
///
/// Refreshing all of them is the honest default: invalidating a provider
/// nothing is watching costs nothing, since it only refetches when something
/// reads it next. The ones that are off-screen simply go cold.
///
/// [listingId] adds that listing's own detail page, when the change was to a
/// listing the caller can name.
void invalidateListingViews(WidgetRef ref, {String? listingId}) {
  ref.invalidate(homeFeedControllerProvider);
  ref.invalidate(searchControllerProvider);
  ref.invalidate(myListingsControllerProvider);
  ref.invalidate(favoritesControllerProvider);
  ref.invalidate(homeStatsControllerProvider);
  if (listingId != null) ref.invalidate(listingDetailControllerProvider(listingId));
}
