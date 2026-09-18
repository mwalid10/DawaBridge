import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_exchange_egypt/features/deals/deal.dart';

void main() {
  group('DealState', () {
    test('parses every value the deal_status enum can return', () {
      expect(DealState.fromString('pending'), DealState.pending);
      expect(DealState.fromString('accepted'), DealState.accepted);
      expect(DealState.fromString('declined'), DealState.declined);
      expect(DealState.fromString('completed'), DealState.completed);
      expect(DealState.fromString('cancelled'), DealState.cancelled);
    });

    test('falls back to cancelled for an unknown value rather than throwing', () {
      // An older client meeting a state added server-side should degrade,
      // not crash the chat list.
      expect(DealState.fromString('something_new'), DealState.cancelled);
    });

    test('only pending and accepted are live', () {
      expect(DealState.pending.isLive, isTrue);
      expect(DealState.accepted.isLive, isTrue);
      expect(DealState.declined.isLive, isFalse);
      expect(DealState.completed.isLive, isFalse);
      expect(DealState.cancelled.isLive, isFalse);
    });

    test('only pending awaits the seller', () {
      expect(DealState.pending.awaitsSeller, isTrue);
      for (final s in DealState.values.where((s) => s != DealState.pending)) {
        expect(s.awaitsSeller, isFalse, reason: '$s');
      }
    });
  });

  group('Deal.fromJson', () {
    Map<String, dynamic> row(Map<String, dynamic> overrides) => {
          'deal_id': 'd1',
          'listing_id': 'l1',
          'drug_trade_name': 'Panadol',
          'listing_type': 'sell',
          'deal_state': 'pending',
          'is_seller': true,
          'counterpart_id': 'p2',
          'counterpart_name': 'El Nahda Pharmacy',
          'last_message': null,
          'last_message_at': null,
          'expires_at': null,
          'unread_count': null,
          'created_at': '2026-09-18T10:00:00.000Z',
          ...overrides,
        };

    test('reads the new expires_at and unread_count columns', () {
      final deal = Deal.fromJson(row({
        'expires_at': '2026-09-20T10:00:00.000Z',
        'unread_count': 3,
      }));
      expect(deal.expiresAt, DateTime.parse('2026-09-20T10:00:00.000Z'));
      expect(deal.unreadCount, 3);
    });

    test('tolerates a null unread_count', () {
      expect(Deal.fromJson(row({})).unreadCount, 0);
      expect(Deal.fromJson(row({})).expiresAt, isNull);
    });
  });
}
