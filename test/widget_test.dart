// Basic smoke test — verifies the app boots to the splash screen without
// throwing, without depending on a live Supabase connection.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_exchange_egypt/features/splash/splash_screen.dart';

void main() {
  testWidgets('Splash screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    expect(find.byIcon(Icons.local_pharmacy_rounded), findsOneWidget);

    // The splash no longer decides where to go — that moved to the router's
    // redirect (see router_redirect_test.dart). It still schedules a short
    // Future.delayed to nudge the router once the session resolves, so
    // unmount before advancing the clock: the callback's `mounted` check
    // then makes it a no-op and teardown doesn't see a pending timer.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 600));
  });
}
