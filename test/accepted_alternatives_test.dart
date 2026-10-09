import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_exchange_egypt/features/listings/listing_detail_controller.dart';

/// An exchange listing's "accepts in exchange" chips are drug ids resolved to
/// rows. They were resolved against the picker's catalogue, which excludes
/// drugs awaiting admin review — so a pharmacy that named three of those got
/// no section at all, which was every exchange listing carrying alternatives
/// in the live database.
void main() {
  Map<String, dynamic> row(String id, String name) => {
        'id': id,
        'trade_name': name,
        'active_ingredient': null,
        'concentration': null,
        'company': null,
        'pharmaceutical_form': null,
        'is_controlled': false,
      };

  test('drugs come back in the order the pharmacy picked them', () {
    // `in` returns rows in whatever order Postgres finds them.
    final drugs = drugsInChosenOrder(
      ['c', 'a', 'b'],
      [row('a', 'Augmentin'), row('b', 'Brufen'), row('c', 'Concor')],
    );

    expect(drugs.map((d) => d.tradeName), ['Concor', 'Augmentin', 'Brufen']);
  });

  test('an id with no drug row left is dropped, not rendered blank', () {
    final drugs = drugsInChosenOrder(['a', 'gone'], [row('a', 'Augmentin')]);

    expect(drugs.map((d) => d.tradeName), ['Augmentin']);
  });

  test('a drug still awaiting review is an alternative like any other', () {
    // The whole point: nothing here filters on is_pending. The rows arrive
    // from a lookup by id, so review state can't hide a chosen alternative.
    final drugs = drugsInChosenOrder(['pending-id'], [row('pending-id', 'Zyvoxenam')]);

    expect(drugs.map((d) => d.tradeName), ['Zyvoxenam']);
  });

  test('no rows at all yields an empty list rather than throwing', () {
    expect(drugsInChosenOrder(['a'], const []), isEmpty);
  });
}
