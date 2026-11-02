import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_exchange_egypt/core/account_type.dart';
import 'package:pharma_exchange_egypt/core/theme.dart';
import 'package:pharma_exchange_egypt/core/widgets/account_type_pill.dart';
import 'package:pharma_exchange_egypt/core/widgets/listing_type_pill.dart';
import 'package:pharma_exchange_egypt/features/listings/listing_summary.dart';
import 'package:pharma_exchange_egypt/features/listings/widgets/my_listing_tile.dart';
import 'package:pharma_exchange_egypt/l10n/app_localizations.dart';

/// My listings floated its state chip and its edit button over the card's
/// corners with physical `left` and `right`, on the reasoning that the card
/// drew nothing there. True in English only: in Arabic the card mirrors and
/// the overlays didn't, so the chip sat on the type pill and the edit button
/// sat on the photo.
void main() {
  ListingSummary listing({
    bool controlled = false,
    ListingState state = ListingState.available,
    AccountType accountType = AccountType.pharmacy,
  }) =>
      ListingSummary(
        id: '1',
        drugId: 'd1',
        tradeName: 'Zyrtec',
        activeIngredient: null,
        concentration: '10mg',
        company: null,
        pharmaceuticalForm: null,
        isControlled: controlled,
        type: ListingType.sell,
        quantity: 30,
        price: null,
        discountPrice: null,
        description: null,
        expiryDate: DateTime(2027, 5, 6),
        state: state,
        acceptedAlternatives: const [],
        photoUrl: null,
        createdAt: DateTime(2026, 1, 1),
        pharmacyId: 'p1',
        pharmacyName: 'Pharmacy',
        accountType: accountType,
        governorate: 'Luxor',
        area: 'Luxor',
        pharmacyLat: null,
        pharmacyLng: null,
        distanceKm: null,
      );

  Future<void> pumpTile(
    WidgetTester tester,
    Locale locale, {
    bool controlled = false,
    AccountType accountType = AccountType.pharmacy,
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: MyListingTile(listing: listing(controlled: controlled, accountType: accountType)),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// The state chip is the only text in the tile that isn't the card's own.
  Finder stateChip(WidgetTester tester) => find.text(
        AppLocalizations.of(tester.element(find.byType(MyListingTile)))!.listingStateAvailable,
      );

  for (final (name, locale) in [('English', Locale('en')), ('Arabic', Locale('ar'))]) {
    group(name, () {
      testWidgets('the state chip keeps off the type pill', (tester) async {
        await pumpTile(tester, locale);

        final chip = tester.getRect(stateChip(tester));
        final pill = tester.getRect(find.byType(ListingTypePill));

        expect(chip.overlaps(pill), isFalse, reason: 'state chip $chip is sitting on the type pill $pill');
      });

      testWidgets('the edit button keeps off the photo', (tester) async {
        await pumpTile(tester, locale);

        final edit = tester.getRect(find.byIcon(Icons.edit_outlined));
        // The thumbnail is the card's leading child; its placeholder icon
        // stands in for the photo.
        final photo = tester.getRect(find.byIcon(Icons.medication_rounded));

        expect(edit.overlaps(photo), isFalse, reason: 'edit button $edit is sitting on the photo $photo');
      });

      testWidgets('the controlled-substance badge keeps off the state chip', (tester) async {
        await pumpTile(tester, locale, controlled: true);

        final badge = tester.getRect(find.byIcon(Icons.warning_amber_rounded));
        final chip = tester.getRect(stateChip(tester));

        expect(badge.overlaps(chip), isFalse, reason: 'the two badges share the thumbnail corner');
      });

      testWidgets('nothing overflows the card', (tester) async {
        await pumpTile(tester, locale, controlled: true);

        // A RenderFlex overflow paints the striped banner and reports here.
        expect(tester.takeException(), isNull);
      });

      // A warehouse listing adds a third chip to the title row, which in
      // Arabic is the row that already broke once — hence the same two
      // checks again with the badge present, not just on the pharmacy case.
      testWidgets('the warehouse badge keeps off the state chip', (tester) async {
        await pumpTile(tester, locale, accountType: AccountType.warehouse);

        final badge = tester.getRect(find.byType(AccountTypePill));
        final chip = tester.getRect(stateChip(tester));

        expect(badge.overlaps(chip), isFalse, reason: 'warehouse badge $badge is sitting on the state chip $chip');
      });

      testWidgets('nothing overflows the card for a warehouse', (tester) async {
        await pumpTile(tester, locale, controlled: true, accountType: AccountType.warehouse);

        expect(find.byType(AccountTypePill), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a pharmacy listing carries no account badge', (tester) async {
        await pumpTile(tester, locale);

        expect(find.byType(AccountTypePill), findsNothing);
      });
    });
  }

  testWidgets('a listing that cannot be edited has no edit button', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: MyListingTile(listing: listing(state: ListingState.completed))),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });
}
