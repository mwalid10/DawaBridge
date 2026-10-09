import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_exchange_egypt/core/connectivity.dart';
import 'package:pharma_exchange_egypt/core/widgets/offline_banner.dart';
import 'package:pharma_exchange_egypt/l10n/app_localizations.dart';

/// The strip wraps every screen in the app, so "it floats over whatever is
/// underneath" was never cosmetic: offline in a chat thread it covered the
/// back button and sliced the title in half, and the way out of the screen
/// went with them.
void main() {
  const statusBar = 44.0;

  Widget harness() => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => OfflineBanner(child: child ?? const SizedBox.shrink()),
        home: Scaffold(
          appBar: AppBar(
            leading: const BackButton(),
            title: const Text('Chat'),
          ),
          body: const SizedBox.expand(),
        ),
      );

  // The whole strip, status bar inset included — its SafeArea is the
  // outermost thing the pulsing cloud icon sits inside.
  Rect strip(WidgetTester tester) => tester.getRect(
        find.ancestor(of: find.byIcon(Icons.cloud_off_rounded), matching: find.byType(SafeArea)).first,
      );

  Future<void> goOffline(WidgetTester tester) async {
    connectivityController.reportFailure();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  // Also settles the icon's repeating pulse, which otherwise outlives the
  // test and trips the binding's "timer still pending" check.
  Future<void> goOnline(WidgetTester tester) async {
    connectivityController.reportSuccess();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.padding = FakeViewPadding(top: statusBar * view.devicePixelRatio);
    view.viewPadding = FakeViewPadding(top: statusBar * view.devicePixelRatio);
    addTearDown(view.resetPadding);
    addTearDown(view.resetViewPadding);
    // Global singleton — leave it as we found it for whatever runs next.
    addTearDown(connectivityController.reportSuccess);
  });

  testWidgets('the strip takes its own space rather than covering the app bar', (tester) async {
    await tester.pumpWidget(harness());

    expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
    // Online, the app bar owns the status bar inset itself.
    expect(tester.getTopLeft(find.byType(AppBar)).dy, 0);
    final onlineTitleTop = tester.getTopLeft(find.text('Chat')).dy;

    await goOffline(tester);

    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    expect(strip(tester).bottom, tester.getRect(find.byType(AppBar)).top,
        reason: 'the strip must end exactly where the app bar begins');
    expect(tester.getRect(find.byType(BackButton)).top,
        greaterThanOrEqualTo(strip(tester).bottom),
        reason: 'the back button is the way out of the screen — it cannot be buried');
    expect(tester.getTopLeft(find.text('Chat')).dy, greaterThan(onlineTitleTop),
        reason: 'the app should be pushed down, not painted over');

    await goOnline(tester);
  });

  testWidgets('the status bar inset is not paid for twice', (tester) async {
    await tester.pumpWidget(harness());
    final onlineTitle = tester.getRect(find.text('Chat'));

    await goOffline(tester);

    // The strip carries the inset, so the app below it drops by the strip's
    // *content* height alone. If both claimed the inset the title would sit
    // another 44pt down, under a band of empty app-bar colour.
    final contentHeight = strip(tester).height - statusBar;
    expect(
      tester.getRect(find.text('Chat')).top - onlineTitle.top,
      closeTo(contentHeight, 0.01),
      reason: 'the app dropped by more than the strip is tall',
    );

    await goOnline(tester);
  });

  testWidgets('reconnecting gives the space back', (tester) async {
    await tester.pumpWidget(harness());
    final onlineTitle = tester.getRect(find.text('Chat'));

    await goOffline(tester);
    await goOnline(tester);

    expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
    expect(tester.getRect(find.text('Chat')), onlineTitle);
  });
}
