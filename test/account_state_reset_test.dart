import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_exchange_egypt/core/account_state_reset.dart';

/// Signing out and back in as another pharmacy used to leave the previous
/// account's data in the root provider container — its name on Home, its
/// listings in the feed — until the process was killed. The fix is only as
/// good as the list of providers it resets, and that list is exactly the kind
/// of thing that silently rots as controllers are added.
void main() {
  test('every provider in the app is either reset on account change or named as exempt', () {
    final declaration = RegExp(r'^final ([A-Za-z_][A-Za-z0-9_]*Provider)\b', multiLine: true);

    final declared = <String, String>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final match in declaration.allMatches(entity.readAsStringSync())) {
        final name = match.group(1)!;
        // Private providers can't be referenced from account_state_reset.dart
        // at all. They're required to be autoDispose instead, so they cannot
        // outlive the screen that reads them — let alone the session.
        if (name.startsWith('_')) continue;
        declared[name] = entity.path;
      }
    }

    // A guard on the guard: if the regex ever stops matching how providers are
    // declared, every assertion below would pass vacuously.
    expect(declared.length, greaterThan(20), reason: 'provider declarations are no longer being found');

    final source = File('lib/core/account_state_reset.dart').readAsStringSync();
    final unaccounted = declared.entries.where((e) => !source.contains(e.key)).toList();

    expect(
      unaccounted.map((e) => '${e.key}  (${e.value})').toList(),
      isEmpty,
      reason: 'Add each of these to AccountStateReset.reset(), or to the list of '
          'deliberately exempt providers in that file\'s doc comment, saying why '
          'the next user may safely see the last user\'s copy of it.',
    );
  });

  group('what counts as a change of account', () {
    test('a different pharmacy signing in does', () {
      expect(AccountStateReset.shouldReset('pharmacy-a', 'pharmacy-b'), isTrue);
    });

    test('the first sign-in of a run does', () {
      expect(AccountStateReset.shouldReset(null, 'pharmacy-a'), isTrue);
    });

    test('signing back in as the same pharmacy does', () {
      // Arrives as two events. The sign-out half is not a reset (see
      // shouldReset), the sign-in half is — otherwise a user who signs out
      // and straight back in keeps every stale list they had before.
      expect(AccountStateReset.shouldReset('pharmacy-a', null), isFalse);
      expect(AccountStateReset.shouldReset(null, 'pharmacy-a'), isTrue);
    });

    test('an hourly token refresh does not', () {
      // Fires several times a session. Wiping the app's state on each one
      // would blank whatever the user is reading and refetch all of it.
      expect(AccountStateReset.shouldReset('pharmacy-a', 'pharmacy-a'), isFalse);
    });

    test('signing out does not, on its own', () {
      expect(AccountStateReset.shouldReset('pharmacy-a', null), isFalse);
    });
  });

  test('resetting a container that has built nothing is harmless', () {
    // Every call in reset() is a real provider that invalidate() accepts —
    // including the families, where it invalidates each live member. Nothing
    // is built here, so nothing reaches the network.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(() => AccountStateReset.reset(container), returnsNormally);
  });
}
