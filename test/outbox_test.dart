import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_exchange_egypt/features/chat/message.dart';
import 'package:pharma_exchange_egypt/features/chat/outbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  PendingMessage pending(String dealId, String body, {DateTime? at}) => PendingMessage(
        id: MessageOutbox.newId(),
        dealId: dealId,
        senderId: 'me',
        body: body,
        createdAt: at ?? DateTime.now(),
      );

  group('MessageOutbox', () {
    test('queues and reads back', () async {
      await MessageOutbox.add(pending('deal-1', 'hello'));
      final queue = await MessageOutbox.all();
      expect(queue, hasLength(1));
      expect(queue.first.body, 'hello');
    });

    test('scopes to one thread', () async {
      await MessageOutbox.add(pending('deal-1', 'a'));
      await MessageOutbox.add(pending('deal-2', 'b'));

      expect(await MessageOutbox.forDeal('deal-1'), hasLength(1));
      expect((await MessageOutbox.forDeal('deal-1')).first.body, 'a');
    });

    test('returns a thread oldest-first', () async {
      // Order within a thread is the one thing that has to survive queuing.
      final now = DateTime.now();
      await MessageOutbox.add(pending('d', 'third', at: now.add(const Duration(seconds: 2))));
      await MessageOutbox.add(pending('d', 'first', at: now));
      await MessageOutbox.add(pending('d', 'second', at: now.add(const Duration(seconds: 1))));

      final queue = await MessageOutbox.forDeal('d');
      expect(queue.map((m) => m.body), ['first', 'second', 'third']);
    });

    test('ids are unique, so a retry can collide on the primary key', () async {
      // This is what makes flushing idempotent: an attempt that reached the
      // server but lost the response retries into a PK conflict rather than
      // posting the message a second time.
      final ids = List.generate(200, (_) => MessageOutbox.newId());
      expect(ids.toSet(), hasLength(200));
    });

    test('survives a round trip through storage', () async {
      final original = pending('deal-1', 'persisted');
      await MessageOutbox.add(original);

      final restored = (await MessageOutbox.all()).first;
      expect(restored.id, original.id);
      expect(restored.dealId, original.dealId);
      expect(restored.senderId, original.senderId);
      expect(restored.body, original.body);
      expect(restored.attempts, 0);
    });

    test('clear empties the queue', () async {
      await MessageOutbox.add(pending('deal-1', 'x'));
      await MessageOutbox.clear();
      // An unsent message must not be flushed under whoever signs in next.
      expect(await MessageOutbox.all(), isEmpty);
    });
  });

  group('Message.pending', () {
    test('renders a queued message as pending, not delivered', () async {
      final p = pending('deal-1', 'typed offline');
      final message = Message.pending(p);

      expect(message.isPending, isTrue);
      expect(message.id, p.id);
      expect(message.body, 'typed offline');
      expect(message.senderId, 'me');
    });

    test('a message read from the server is never pending', () {
      final message = Message.fromJson({
        'id': 'x',
        'deal_id': 'd',
        'sender_id': 'me',
        'body': 'delivered',
        'created_at': '2026-09-19T10:00:00.000Z',
      });
      expect(message.isPending, isFalse);
    });
  });
}
