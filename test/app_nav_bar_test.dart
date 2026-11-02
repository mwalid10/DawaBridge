import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_exchange_egypt/core/theme.dart';
import 'package:pharma_exchange_egypt/core/widgets/gradient_fab.dart';
import 'package:pharma_exchange_egypt/features/home/app_nav_bar.dart';

/// The bar used to put two destinations in one half and three in the other
/// around a fixed gap for the Add button, which left the spacing on the left
/// visibly different from the right, and docked the button so its middle sat
/// on the bar's top edge — which with equal slots would bury the middle
/// destination.
void main() {
  const destinations = [
    AppNavDestination(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home', index: 0),
    AppNavDestination(icon: Icons.search_rounded, selectedIcon: Icons.search_rounded, label: 'Search', index: 1),
    AppNavDestination(icon: Icons.chat_bubble_outline_rounded, selectedIcon: Icons.chat_bubble_rounded, label: 'Chat', index: 3),
    AppNavDestination(icon: Icons.newspaper_outlined, selectedIcon: Icons.newspaper_rounded, label: 'News', index: 4),
    AppNavDestination(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile', index: 5),
  ];

  Future<void> pumpBar(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: const SizedBox.expand(),
        floatingActionButton: GradientFab(icon: Icons.add_rounded, onPressed: () {}),
        floatingActionButtonLocation: const AboveNavBarFabLocation(),
        bottomNavigationBar: AppNavBar(
          selectedIndex: 0,
          onSelect: (_) {},
          destinations: destinations,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder slots() => find.descendant(of: find.byType(AppNavBar), matching: find.byType(InkWell));

  List<double> slotWidths(WidgetTester tester, int count) =>
      [for (var i = 0; i < count; i++) tester.getSize(slots().at(i)).width];

  testWidgets('every destination gets the same width', (tester) async {
    await pumpBar(tester);

    expect(slots(), findsNWidgets(destinations.length));
    final widths = slotWidths(tester, destinations.length);

    expect(widths.toSet(), hasLength(1), reason: 'the destinations are not evenly divided: $widths');
  });

  testWidgets('the Add button dips into the bar without reaching a destination', (tester) async {
    await pumpBar(tester);

    // AppNavBar's own padding is below the bar, so the widget's top edge is
    // the bar's top edge — which is what AboveNavBarFabLocation measures
    // against.
    final barTop = tester.getRect(find.byType(AppNavBar)).top;
    final fab = tester.getRect(find.byType(GradientFab));

    expect(fab.bottom - barTop, closeTo(AppNavBar.fabDip, 0.01),
        reason: 'the button no longer seats in its notch');
    // The notch is cut around the button, so whatever the button clears the
    // notch clears too. The middle destination lives directly under both.
    final middleIcon = tester.getRect(find.byIcon(Icons.chat_bubble_outline_rounded));
    expect(fab.bottom, lessThan(middleIcon.top),
        reason: 'the notch has eaten into the destination beneath it');
    // Centred, so it reads as belonging to the bar rather than to a corner.
    expect(fab.center.dx, closeTo(tester.getRect(find.byType(AppNavBar)).center.dx, 0.5));
  });

  testWidgets('the bar is notched for the button rather than running straight across', (tester) async {
    await pumpBar(tester);

    final bar = tester.getRect(find.byType(AppNavBar));
    // The shape in its own coordinates, as Material paints it.
    final local = Rect.fromLTWH(0, 0, bar.width, AppNavBar.barHeight);
    final path = const NotchedBarBorder(radius: AppRadius.xl).getOuterPath(local);

    // Just inside the top edge: a hole under the button, bar everywhere else.
    expect(path.contains(Offset(local.center.dx, 2)), isFalse,
        reason: 'the top edge runs straight under the Add button — no notch');
    expect(path.contains(Offset(local.center.dx - 90, 2)), isTrue);
    expect(path.contains(Offset(local.center.dx + 90, 2)), isTrue);
    // Wider than the button it holds, or it reads as a slot rather than a
    // curve: the cut still clears the top edge 2pt out past the button's own
    // radius on both sides.
    final pastTheButton = AppNavBar.fabSize / 2 + 2;
    expect(path.contains(Offset(local.center.dx - pastTheButton, 2)), isFalse);
    expect(path.contains(Offset(local.center.dx + pastTheButton, 2)), isFalse);
    // And it really is a bite out of the top, not a hole through the bar.
    expect(path.contains(Offset(local.center.dx, AppNavBar.barHeight - 2)), isTrue);
  });

  testWidgets('a white bar on a white page is held apart by a green glow', (tester) async {
    // Measured off the rendered pixels, not off a shadowColor property: the
    // bar and the page behind it are both AppColors.surface, so "can you see
    // the bar at all" is a question about what actually lands on screen.
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: AppColors.surface,
          child: Scaffold(
            backgroundColor: AppColors.surface,
            body: const SizedBox.expand(),
            bottomNavigationBar: AppNavBar(selectedIndex: 0, onSelect: (_) {}, destinations: destinations),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    late final ByteData pixels;
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      image.dispose();
    });

    final width = tester.getSize(find.byKey(key)).width.round();
    Color at(Offset p) {
      final i = ((p.dy.round() * width) + p.dx.round()) * 4;
      final b = pixels.buffer.asUint8List();
      return Color.fromARGB(b[i + 3], b[i], b[i + 1], b[i + 2]);
    }

    final bar = tester.getRect(find.byType(AppNavBar));
    // Just under the bar's bottom edge, where the glow falls.
    final below = at(Offset(bar.center.dx, bar.top + AppNavBar.barHeight + 6));

    expect(below, isNot(AppColors.surface), reason: 'the bar has no visible edge against the page');
    expect(below.g, greaterThan(below.r), reason: 'the glow has lost its green');
    expect(below.g, greaterThan(below.b));
  });

  testWidgets('tapping a destination reports its tab index, not its slot', (tester) async {
    // The Add screen holds a slot in the shell's tab list without having a
    // destination here, so the last one is index 5 of 6 rather than 4 of 5.
    int? tapped;
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: AppNavBar(
          selectedIndex: 0,
          onSelect: (i) => tapped = i,
          destinations: destinations,
        ),
      ),
    ));

    await tester.tap(find.text('Profile'));
    expect(tapped, 5);
  });

  testWidgets('the slots stay even in Arabic, where the labels are longer', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: AppNavBar(
            selectedIndex: 0,
            onSelect: (_) {},
            destinations: const [
              AppNavDestination(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'الرئيسية', index: 0),
              AppNavDestination(icon: Icons.search_rounded, selectedIcon: Icons.search_rounded, label: 'بحث', index: 1),
              AppNavDestination(icon: Icons.chat_bubble_outline_rounded, selectedIcon: Icons.chat_bubble_rounded, label: 'المحادثات', index: 3),
              AppNavDestination(icon: Icons.newspaper_outlined, selectedIcon: Icons.newspaper_rounded, label: 'الأخبار', index: 4),
              AppNavDestination(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'حسابي', index: 5),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final widths = slotWidths(tester, 5).toSet();

    expect(widths, hasLength(1), reason: 'a long label stretched its slot: $widths');
    expect(tester.takeException(), isNull, reason: 'a label overflowed the bar');
  });
}
