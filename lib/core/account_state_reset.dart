import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/add_medicine/add_medicine_controller.dart';
import '../features/chat/messages_controller.dart';
import '../features/deals/deals_controller.dart';
import '../features/disputes/disputes_controller.dart';
import '../features/drugs/drugs_controller.dart';
import '../features/favorites/favorite_controller.dart';
import '../features/favorites/favorites_controller.dart';
import '../features/home/home_feed_controller.dart';
import '../features/home/home_stats_controller.dart';
import '../features/home/price_increased_controller.dart';
import '../features/kyc/kyc_controller.dart';
import '../features/listings/listing_detail_controller.dart';
import '../features/listings/my_listings_controller.dart';
import '../features/news/news_controller.dart';
import '../features/notifications/notifications_controller.dart';
import '../features/profile/profile_controller.dart';
import '../features/push/push_token_controller.dart';
import '../features/ratings/ratings_controller.dart';
import '../features/search/search_controller.dart';
import 'supabase_client.dart';

/// Drops every cached provider when the signed-in account changes.
///
/// Riverpod's root container lives as long as the process does, and almost
/// every controller in this app is a root-scoped `AsyncNotifierProvider` —
/// nothing about signing out disposes them. So signing out and back in as a
/// different pharmacy left the previous account's profile, feed, deals,
/// listings and favourites sitting in memory: the new user was greeted by the
/// old user's name on Home and browsed the old user's data until the app was
/// killed and relaunched. Pull-to-refresh only rebuilt whichever single list
/// was in front of them, which is why it took several goes.
///
/// `OfflineCache.clear()` and `MessageOutbox.clear()` already did this for the
/// two stores on disk (see the sign-out path in `account_settings_screen.dart`
/// and the comment there about whoever signs in on this device next). This is
/// the same guarantee for the store in memory, which was the largest of the
/// three — with one difference: the disk stores are cleared on the way out,
/// this one on the way back in (see [start]). Nothing renders the difference
/// visible, because the screens in between are the auth screens.
///
/// The list in [reset] is exhaustive by test, not by discipline:
/// `test/account_state_reset_test.dart` reads every provider declared under
/// `lib/` and fails if one is neither reset here nor named below as
/// deliberately exempt. A controller added next month is a failing test, not a
/// bug report about a stale name on the home screen.
///
/// Deliberately exempt, and why:
///
///   * [localeControllerProvider] — belongs to the handset, not the account.
///     Resetting the chosen language mid-sign-in would flip an Arabic user's
///     app, including the whole RTL layout, back to the device default.
///   * [connectivityProvider], [sessionControllerProvider] — these expose
///     app-wide singletons that outlive any session. Recomputing them yields
///     the identical instance, so it would notify nobody and change nothing.
///   * `_allPriceAlertsProvider` (price_alerts_screen.dart) — private and
///     `autoDispose`, so it is gone the moment its screen is popped and can't
///     survive to another account. Private providers are unreachable from
///     here by construction; keep them `autoDispose` for this reason.
class AccountStateReset {
  AccountStateReset._();

  static String? _accountId;
  static StreamSubscription<AuthState>? _sub;

  /// Called once from `main()`, before `runApp`.
  static void start(ProviderContainer container) {
    _accountId = supabase.auth.currentUser?.id;
    _sub ??= supabase.auth.onAuthStateChange.listen((event) {
      final previous = _accountId;
      _accountId = event.session?.user.id;
      if (shouldReset(previous, _accountId)) reset(container);
    });
  }

  /// Whether moving from [previous] to [next] means a different account is
  /// now using the app.
  ///
  /// `onAuthStateChange` fires for hourly token refreshes and profile updates
  /// too, where wiping everything would be a stall and a burst of refetches
  /// for nothing — so an unchanged id is not an account change.
  ///
  /// Signing *out* isn't one either, deliberately. It leaves the screens below
  /// the one that did it still mounted underneath (routes in the stack aren't
  /// disposed until the redirect lands), and invalidating what they watch
  /// would fire half a dozen refetches with no session attached — several of
  /// them writing empty results straight back into the cache that sign-out
  /// had just cleared. Waiting for the next sign-in costs nothing: the only
  /// screens reachable in between are the auth ones, which read none of this.
  ///
  /// Signing back in as the *same* account still resets, because it arrives
  /// as a change to null and then a change back.
  @visibleForTesting
  static bool shouldReset(String? previous, String? next) => next != null && next != previous;

  /// Invalidates every account-scoped provider.
  ///
  /// Plain `invalidate`, never `asReload`: a reload keeps the old value
  /// visible underneath the spinner, and the old value here belongs to the
  /// account that just left.
  static void reset(ProviderContainer container) {
    // Who you are.
    container.invalidate(pharmacyProfileControllerProvider);
    container.invalidate(ratingSummaryControllerProvider);
    container.invalidate(kycControllerProvider);
    // Re-registers this handset's push token against the new account.
    container.invalidate(pushTokenControllerProvider);

    // What you're looking at.
    container.invalidate(homeFeedControllerProvider);
    container.invalidate(homeStatsControllerProvider);
    container.invalidate(searchControllerProvider);
    container.invalidate(myListingsControllerProvider);
    container.invalidate(favoritesControllerProvider);
    container.invalidate(favoriteControllerProvider);
    container.invalidate(listingDetailControllerProvider);
    container.invalidate(acceptedAlternativeDrugsProvider);
    container.invalidate(priceIncreasedControllerProvider);
    container.invalidate(newsControllerProvider);
    container.invalidate(drugsControllerProvider);

    // Who you're dealing with.
    container.invalidate(dealsControllerProvider);
    container.invalidate(pendingSellerRequestsProvider);
    container.invalidate(dealDetailControllerProvider);
    container.invalidate(messagesControllerProvider);
    container.invalidate(disputesControllerProvider);
    container.invalidate(currentDisputeControllerProvider);
    container.invalidate(hasRatedControllerProvider);
    container.invalidate(notificationsControllerProvider);
    container.invalidate(unreadNotificationsCountProvider);

    // Half-finished work. A draft listing typed by the last user must not be
    // waiting in the form for the next one.
    container.invalidate(addMedicineControllerProvider);
  }

  @visibleForTesting
  static void stop() {
    _sub?.cancel();
    _sub = null;
    _accountId = null;
  }
}
