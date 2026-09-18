import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/connectivity.dart';
import 'core/locale_controller.dart';
import 'core/router.dart';
import 'core/session.dart';
import 'core/supabase_client.dart';
import 'core/theme.dart';
import 'core/widgets/offline_banner.dart';
import 'features/chat/outbox.dart';
import 'l10n/app_localizations.dart';

/// Runs in a separate isolate when a push arrives while the app is
/// terminated/backgrounded. Deliberately does nothing — a "notification"
/// (as opposed to "data-only") FCM message is already shown by the OS
/// without any app code running; this handler just has to exist so
/// `onBackgroundMessage` is satisfied.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {}

/// True once Firebase actually came up. Push registration checks this so it
/// doesn't call into an uninitialized SDK.
bool firebaseReady = false;

/// Routes a push tap to whatever it's about.
///
/// Nothing handled taps before — pushes only ever came from the admin
/// broadcast function and carried no payload, so tapping one just opened the
/// app on whatever screen it was last on. Now that the database pushes
/// message and deal events (`send-push`, migration 0042) and includes
/// `deal_id` / `listing_id` in the data payload, a tap should land on the
/// thing it's telling you about.
Future<void> _wireNotificationTaps() async {
  // App was terminated and launched by tapping the notification.
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) _handleNotificationTap(initial);

  // App was backgrounded and resumed by a tap.
  FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
}

void _handleNotificationTap(RemoteMessage message) {
  final dealId = message.data['deal_id'] as String?;
  final listingId = message.data['listing_id'] as String?;

  // Push the destination rather than replacing the stack, so the router's
  // redirect still gets to veto it — a suspended pharmacy tapping an old
  // notification must not be dropped into a deal thread.
  if (dealId != null && dealId.isNotEmpty) {
    appRouter.push('/chat/$dealId');
  } else if (listingId != null && listingId.isNotEmpty) {
    appRouter.push('/listing/$listingId');
  } else {
    appRouter.push('/notifications');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Firebase is optional at runtime, and deliberately so: there is no
  // `ios/Runner/GoogleService-Info.plist` in the repo (it has to be
  // generated from the Firebase console and added to the Xcode project).
  // `Firebase.initializeApp()` throws without it, and because this ran
  // unguarded before `runApp`, the iOS build crashed on launch every time —
  // the app could not start at all on iOS. Push notifications are a feature;
  // starting the app is not optional, so a missing config now degrades
  // gracefully instead of being fatal.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    firebaseReady = true;
    await _wireNotificationTaps();
  } catch (error, stack) {
    firebaseReady = false;
    debugPrint(
      'Firebase init failed — push notifications disabled for this run. '
      'On iOS this usually means ios/Runner/GoogleService-Info.plist is missing.\n'
      '$error\n$stack',
    );
  }

  // Read the saved language before the first frame. Loading it afterwards
  // made every cold start render in the device language and then snap — a
  // full LTR/RTL flip for an Arabic user on an English handset.
  await LocaleController.preload();

  await initSupabase();

  // Nothing listened to auth state before this, so an expired or revoked
  // session produced errors on every screen instead of returning the user
  // to sign-in, and `pharmacies.status` was never consulted at all.
  connectivityController.start();
  sessionController.start();
  // Flushes anything typed offline — including from a previous run, if the
  // app was killed with messages still queued.
  MessageOutbox.start();

  // Password recovery deep link. The email's link carries a recovery token;
  // supabase_flutter exchanges it for a session and emits this event. Before
  // this there was no listener and no screen, so the reset flow dead-ended.
  supabase.auth.onAuthStateChange.listen((event) {
    if (event.event == AuthChangeEvent.passwordRecovery) {
      appRouter.go('/reset-password');
    }
  });

  runApp(const ProviderScope(child: PharmaExchangeApp()));
}

class PharmaExchangeApp extends ConsumerWidget {
  const PharmaExchangeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    return MaterialApp.router(
      title: 'DawaBridge',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Deliberately light-only for now. A dark ThemeData on its own would
      // make things worse, not better: roughly ninety widgets across the app
      // paint from the `AppColors` static constants directly
      // (AppColors.surface, AppColors.ink, ...) rather than from
      // `Theme.of(context)`, so flipping this to ThemeMode.system would give
      // a dark scaffold with white cards and near-white text on them.
      // Enabling dark mode is a palette migration — move AppColors to a
      // ThemeExtension and convert those call sites — not a themeMode flag.
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // Wraps every screen: "why did that fail?" can be asked from anywhere.
      builder: (context, child) => OfflineBanner(child: child ?? const SizedBox.shrink()),
    );
  }
}
