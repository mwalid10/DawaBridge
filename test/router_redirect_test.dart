import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_exchange_egypt/core/router.dart';
import 'package:pharma_exchange_egypt/core/session.dart';

/// The auth/KYC gate.
///
/// These cover the specific hole that existed before: the app had no router
/// redirect at all, so every route was reachable by deep link with no
/// session, and an unapproved pharmacy reached the full marketplace just by
/// signing out and back in.
void main() {
  group('signed out', () {
    test('may reach the public routes', () {
      for (final route in ['/', '/onboarding', '/login', '/register', '/register/otp']) {
        expect(resolveRedirect(SessionState.signedOut, route), isNull, reason: route);
      }
    });

    test('is bounced off every authenticated route', () {
      for (final route in ['/home', '/my-listings', '/favorites', '/chat/abc', '/listing/abc', '/notifications']) {
        expect(resolveRedirect(SessionState.signedOut, route), '/onboarding', reason: route);
      }
    });
  });

  group('not approved', () {
    // The whole point of the KYC gate: pending/rejected/suspended must not
    // reach the marketplace, from any entry point including a deep link.
    for (final state in [SessionState.pending, SessionState.rejected, SessionState.suspended]) {
      test('$state cannot reach the marketplace', () {
        for (final route in ['/home', '/my-listings', '/listing/abc', '/chat/abc', '/favorites']) {
          expect(resolveRedirect(state, route), '/account-status', reason: '$state -> $route');
        }
      });

      test('$state can still reach account settings, to sign out or delete', () {
        expect(resolveRedirect(state, '/profile/account'), isNull);
        expect(resolveRedirect(state, '/account-status'), isNull);
      });
    }
  });

  group('approved', () {
    test('reaches the marketplace', () {
      for (final route in ['/home', '/my-listings', '/listing/abc', '/chat/abc']) {
        expect(resolveRedirect(SessionState.approved, route), isNull, reason: route);
      }
    });

    test('is moved off the entry screens', () {
      for (final route in ['/', '/onboarding', '/login', '/register', '/account-status']) {
        expect(resolveRedirect(SessionState.approved, route), '/home', reason: route);
      }
    });
  });

  group('orphaned registration', () {
    // A confirmed auth user with no pharmacies row. One of these was already
    // in the live database with no way back into the app.
    test('is routed into the recovery flow from anywhere', () {
      for (final route in ['/', '/home', '/login', '/my-listings']) {
        expect(resolveRedirect(SessionState.needsRegistration, route), '/register/complete', reason: route);
      }
    });

    test('is allowed to stay on the recovery screen', () {
      expect(resolveRedirect(SessionState.needsRegistration, '/register/complete'), isNull);
    });
  });

  group('admin account in the pharmacy app', () {
    test('is held on the status screen, not pushed into KYC recovery', () {
      expect(resolveRedirect(SessionState.admin, '/home'), '/account-status');
      expect(resolveRedirect(SessionState.admin, '/register/complete'), isNull);
    });
  });

  group('while the session is still resolving', () {
    test('holds on the splash rather than flashing a screen', () {
      expect(resolveRedirect(SessionState.unknown, '/'), isNull);
      expect(resolveRedirect(SessionState.unknown, '/home'), '/');
      expect(resolveRedirect(SessionState.unknown, '/login'), '/');
    });
  });

  group('password recovery deep link', () {
    test('is reachable in every session state', () {
      for (final state in SessionState.values) {
        expect(resolveRedirect(state, '/reset-password'), isNull, reason: '$state');
      }
    });
  });
}
