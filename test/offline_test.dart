import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_exchange_egypt/core/connectivity.dart';
import 'package:pharma_exchange_egypt/core/router.dart';
import 'package:pharma_exchange_egypt/core/session.dart';

void main() {
  group('offline routing', () {
    // The bug this whole flow exists for: a cold start with no network left
    // SessionController stuck in `unknown`, and the rule for `unknown` is
    // "hold on the splash". The app sat on the logo forever with no message,
    // no retry, and no way to reach sign-in.
    test('an unresolvable session lands somewhere, not on the splash', () {
      expect(resolveRedirect(SessionState.offline, '/home'), '/offline');
      expect(resolveRedirect(SessionState.offline, '/'), '/offline');
      expect(resolveRedirect(SessionState.offline, '/offline'), isNull);
    });

    test('signing out stays reachable without a connection', () {
      // Otherwise the only escape from the offline screen is reinstalling.
      expect(resolveRedirect(SessionState.offline, '/profile/account'), isNull);
    });

    test('every session state has a defined destination', () {
      // A state with no case would fall through and strand the user.
      for (final state in SessionState.values) {
        expect(
          () => resolveRedirect(state, '/home'),
          returnsNormally,
          reason: '$state',
        );
      }
    });

    test('password recovery still works offline-ish', () {
      expect(resolveRedirect(SessionState.offline, '/reset-password'), isNull);
    });
  });

  group('ConnectivityController.looksOffline', () {
    test('recognises the transport failures Supabase surfaces', () {
      for (final message in [
        'SocketException: Failed host lookup',
        'ClientException with SocketException',
        'Connection closed before full header was received',
        'Connection refused',
        'Connection reset by peer',
        'Network is unreachable',
        'Software caused connection abort',
      ]) {
        expect(
          ConnectivityController.looksOffline(Exception(message)),
          isTrue,
          reason: message,
        );
      }
    });

    test('recognises a timeout', () {
      expect(ConnectivityController.looksOffline(TimeoutException('x')), isTrue);
    });

    test('does not mistake a server rejection for being offline', () {
      // These must keep their real message — telling a pharmacist "you're
      // offline" when the server said "that listing is reserved" is worse
      // than saying nothing.
      for (final message in [
        'LISTING_UNAVAILABLE',
        'PHARMACY_NOT_APPROVED',
        'DEAL_ALREADY_OPEN',
        'duplicate key value violates unique constraint',
      ]) {
        expect(
          ConnectivityController.looksOffline(Exception(message)),
          isFalse,
          reason: message,
        );
      }
    });
  });

  group('ConnectivityController state', () {
    test('starts online and only goes offline on a real failure', () {
      final c = ConnectivityController();
      addTearDown(c.dispose);

      expect(c.isOffline, isFalse);
      c.reportFailure();
      expect(c.isOffline, isTrue);
      c.reportSuccess();
      expect(c.isOffline, isFalse);
    });

    test('emits a reconnect event when a request succeeds after a failure', () async {
      final c = ConnectivityController();
      addTearDown(c.dispose);

      final events = <void>[];
      final sub = c.onReconnected.listen(events.add);
      addTearDown(sub.cancel);

      c.reportFailure();
      c.reportSuccess();
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
    });

    test('does not emit a reconnect event when it was never offline', () async {
      final c = ConnectivityController();
      addTearDown(c.dispose);

      final events = <void>[];
      final sub = c.onReconnected.listen(events.add);
      addTearDown(sub.cancel);

      c.reportSuccess();
      c.reportSuccess();
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
    });
  });
}
