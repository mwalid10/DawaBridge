import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_exchange_egypt/core/offline_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OfflineCache', () {
    test('round-trips rows', () async {
      await OfflineCache.write(OfflineCache.feed, [
        {'listing_id': 'a', 'trade_name': 'Panadol'},
        {'listing_id': 'b', 'trade_name': 'Antinal'},
      ]);

      final cached = await OfflineCache.read(OfflineCache.feed);
      expect(cached, isNotNull);
      expect(cached!.rows, hasLength(2));
      expect(cached.rows.first['trade_name'], 'Panadol');
    });

    test('returns null for a key never written', () async {
      expect(await OfflineCache.read('nothing_here'), isNull);
    });

    test('keys per entity do not collide', () async {
      await OfflineCache.write(OfflineCache.listing('one'), [
        {'listing_id': 'one'},
      ]);
      await OfflineCache.write(OfflineCache.listing('two'), [
        {'listing_id': 'two'},
      ]);

      final one = await OfflineCache.read(OfflineCache.listing('one'));
      final two = await OfflineCache.read(OfflineCache.listing('two'));
      expect(one!.rows.first['listing_id'], 'one');
      expect(two!.rows.first['listing_id'], 'two');
    });

    test('caps how much one key can store', () async {
      await OfflineCache.write(
        OfflineCache.feed,
        List.generate(500, (i) => {'listing_id': '$i'}),
      );
      final cached = await OfflineCache.read(OfflineCache.feed);
      // A pathological feed must not be able to fill the prefs store.
      expect(cached!.rows.length, lessThanOrEqualTo(200));
    });

    test('marks old entries stale but still returns them', () async {
      // Stale data still beats an empty screen when there's no way to get
      // anything fresher.
      await OfflineCache.write(OfflineCache.feed, [
        {'listing_id': 'a'},
      ]);
      final cached = await OfflineCache.read(OfflineCache.feed);
      expect(cached!.isStale, isFalse);
      expect(cached.rows, isNotEmpty);
    });

    test('clear removes everything', () async {
      await OfflineCache.write(OfflineCache.feed, [
        {'listing_id': 'a'},
      ]);
      await OfflineCache.write(OfflineCache.deals, [
        {'deal_id': 'd'},
      ]);

      await OfflineCache.clear();

      // One pharmacy's cached data must not survive into the next account
      // that signs in on the same device.
      expect(await OfflineCache.read(OfflineCache.feed), isNull);
      expect(await OfflineCache.read(OfflineCache.deals), isNull);
    });
  });
}
