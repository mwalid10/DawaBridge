import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/chat/chat_thread_screen.dart';
import '../features/disputes/disputes_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/home/app_shell.dart';
import '../features/home/price_alerts_screen.dart';
import '../features/kyc/account_status_screen.dart';
import '../features/kyc/complete_registration_screen.dart';
import '../features/kyc/kyc_wizard_screen.dart';
import '../features/kyc/otp_verification_screen.dart';
import '../features/listings/edit_listing_screen.dart';
import '../features/listings/listing_detail_screen.dart';
import '../features/listings/my_listings_screen.dart';
import '../features/news/news_article.dart';
import '../features/news/news_detail_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/account_settings_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/splash/splash_screen.dart';
import 'not_found_screen.dart';
import 'session.dart';
import 'success_screen.dart';

/// Routes reachable with no session at all.
const _publicRoutes = {
  '/',
  '/onboarding',
  '/login',
  '/register',
  '/register/otp',
  '/reset-password',
};

/// Routes a signed-in but not-yet-approved pharmacy may still reach.
/// Account settings is included deliberately: it's where Sign out and
/// Delete account live, and trapping someone on a "pending approval" screen
/// with no way to leave or delete their account is its own bug (and an App
/// Store problem).
const _restrictedRoutes = {
  '/account-status',
  '/profile/account',
  '/register/complete',
  '/reset-password',
};

/// Entry/holding screens an approved pharmacy has no reason to be on.
const _entryRoutes = {
  '/',
  '/onboarding',
  '/login',
  '/register',
  '/register/otp',
  '/register/complete',
  '/account-status',
};

/// Decides where a session belongs — the whole auth/KYC gate, as a pure
/// function so it can be tested without a router, a widget tree or a
/// network.
///
/// The app previously had no redirect at all: every route was reachable by
/// deep link with no session, and both splash and login sent any
/// authenticated user straight to `/home` without ever consulting
/// `pharmacies.status`. That made KYC approval optional — sign out, sign
/// back in, and you were in the marketplace whether or not an admin had
/// approved you.
///
/// Returns null to allow [location], or the path to redirect to. Migration
/// 0034 enforces the same rule in RLS so it still holds for anyone talking
/// to PostgREST directly.
String? resolveRedirect(SessionState session, String location) {
  // Password recovery is entered from an email deep link and has to work in
  // every session state, including the half-authenticated recovery one.
  if (location == '/reset-password') return null;

  switch (session) {
    case SessionState.unknown:
      // Still resolving. Hold on the splash so we never flash a screen we're
      // about to redirect away from.
      return location == '/' ? null : '/';

    case SessionState.signedOut:
      return _publicRoutes.contains(location) ? null : '/onboarding';

    case SessionState.needsRegistration:
      return location == '/register/complete' || location == '/profile/account'
          ? null
          : '/register/complete';

    case SessionState.admin:
    case SessionState.pending:
    case SessionState.rejected:
    case SessionState.suspended:
      return _restrictedRoutes.contains(location) ? null : '/account-status';

    case SessionState.approved:
      return _entryRoutes.contains(location) ? '/home' : null;
  }
}

final appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: sessionController,
  errorBuilder: (context, state) => const NotFoundScreen(),
  redirect: (context, state) => resolveRedirect(sessionController.state, state.matchedLocation),
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/register', builder: (context, state) => const KycWizardScreen()),
    GoRoute(path: '/register/otp', builder: (context, state) => const OtpVerificationScreen()),
    GoRoute(path: '/register/complete', builder: (context, state) => const CompleteRegistrationScreen()),
    GoRoute(path: '/account-status', builder: (context, state) => const AccountStatusScreen()),
    GoRoute(path: '/reset-password', builder: (context, state) => const ResetPasswordScreen()),
    GoRoute(path: '/home', builder: (context, state) => const AppShell()),
    GoRoute(
      path: '/listing/:id',
      builder: (context, state) => ListingDetailScreen(listingId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/listing/:id/edit',
      builder: (context, state) => EditListingScreen(listingId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/chat/:dealId',
      builder: (context, state) => ChatThreadScreen(dealId: state.pathParameters['dealId']!),
    ),
    GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
    GoRoute(path: '/disputes', builder: (context, state) => const DisputesScreen()),
    GoRoute(path: '/my-listings', builder: (context, state) => const MyListingsScreen()),
    GoRoute(path: '/favorites', builder: (context, state) => const FavoritesScreen()),
    GoRoute(path: '/price-alerts', builder: (context, state) => const PriceAlertsScreen()),
    GoRoute(path: '/profile/account', builder: (context, state) => const AccountSettingsScreen()),
    GoRoute(path: '/profile/edit', builder: (context, state) => const EditProfileScreen()),
    GoRoute(
      path: '/news/:id',
      builder: (context, state) => NewsDetailScreen(
        articleId: state.pathParameters['id']!,
        article: state.extra as NewsArticle?,
      ),
    ),
    GoRoute(
      path: '/success',
      // `state.extra` is null whenever this route is reached by anything
      // other than a live in-app push — a deep link, or Android restoring
      // the activity after the process was killed. The old hard cast
      // (`state.extra as SuccessArgs`) threw a TypeError in exactly those
      // cases; falling back to the generic args keeps it a screen.
      builder: (context, state) => SuccessScreen(
        args: state.extra is SuccessArgs ? state.extra! as SuccessArgs : SuccessArgs.generic(),
      ),
    ),
  ],
);
