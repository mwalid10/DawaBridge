// Basic smoke test — verifies the app boots to the splash screen without
// throwing, without depending on a live Supabase connection.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharma_exchange_egypt/features/splash/splash_screen.dart';

void main() {
  testWidgets('Splash screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    expect(find.byIcon(Icons.local_pharmacy_rounded), findsOneWidget);
    // SplashScreen schedules a Future.delayed(900ms) navigation timer in
    // initState that calls into Supabase, which this smoke test
    // deliberately never initializes. Unmount the widget first (its
    // `mounted` check then makes the eventual callback a no-op) before
    // advancing past 900ms, so teardown doesn't see a pending timer.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 900));
  });
}
