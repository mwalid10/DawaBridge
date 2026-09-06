import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/chat/chat_thread_screen.dart';
import '../features/disputes/disputes_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/home/app_shell.dart';
import '../features/home/price_alerts_screen.dart';
import '../features/kyc/kyc_wizard_screen.dart';
import '../features/kyc/otp_verification_screen.dart';
import '../features/kyc/pending_approval_screen.dart';
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
import 'success_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  errorBuilder: (context, state) => const NotFoundScreen(),
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/register', builder: (context, state) => const KycWizardScreen()),
    GoRoute(path: '/register/otp', builder: (context, state) => const OtpVerificationScreen()),
    GoRoute(path: '/pending-approval', builder: (context, state) => const PendingApprovalScreen()),
    GoRoute(path: '/home', builder: (context, state) => const AppShell()),
    GoRoute(
      path: '/listing/:id',
      builder: (context, state) => ListingDetailScreen(listingId: state.pathParameters['id']!),
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
      builder: (context, state) => SuccessScreen(args: state.extra as SuccessArgs),
    ),
  ],
);
