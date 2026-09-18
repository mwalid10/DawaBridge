// Smoke test — the app boots to the splash screen and shows the DawaBridge
// branding, without depending on a live Supabase connection.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_exchange_egypt/features/splash/splash_screen.dart';
import 'package:pharma_exchange_egypt/l10n/app_localizations.dart';

void main() {
  testWidgets('Splash screen shows the brand and tagline', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        // The splash reads its strings through `context.l10n`, which
        // force-unwraps `AppLocalizations.of(context)` — so the delegate has
        // to be registered here the way main.dart registers it.
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SplashScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('DawaBridge'), findsOneWidget);
    expect(find.text('Connecting Pharmacies, Sharing Medicines'), findsOneWidget);

    // The splash no longer decides where to go — that moved to the router's
    // redirect (see router_redirect_test.dart). It still schedules a short
    // Future.delayed to nudge the router once the session resolves, so
    // unmount before advancing the clock: the callback's `mounted` check
    // then makes it a no-op and teardown doesn't see a pending timer.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 800));
  });
}
