import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/locale_controller.dart';
import 'core/router.dart';
import 'core/supabase_client.dart';
import 'core/theme.dart';
import 'l10n/app_localizations.dart';

/// Runs in a separate isolate when a push arrives while the app is
/// terminated/backgrounded. Deliberately does nothing — a "notification"
/// (as opposed to "data-only") FCM message is already shown by the OS
/// without any app code running; this handler just has to exist so
/// `onBackgroundMessage` is satisfied.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  await initSupabase();
  runApp(const ProviderScope(child: PharmaExchangeApp()));
}

class PharmaExchangeApp extends ConsumerWidget {
  const PharmaExchangeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    return MaterialApp.router(
      title: 'Pharma Exchange Egypt',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: appRouter,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    );
  }
}
