import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// Where the current session is allowed to be.
enum SessionState {
  /// Still resolving — the splash screen holds here.
  unknown,
  signedOut,

  /// Signed in, but there's no `pharmacies` row. This is the orphaned
  /// registration case: the OTP was verified (so the auth user exists and
  /// is confirmed) but the licence upload or the pharmacy insert never
  /// landed. One such account was already sitting in the live database
  /// with no way back into the app.
  needsRegistration,

  pending,
  rejected,
  suspended,
  approved,

  /// An admin's auth account signed into the pharmacy app. Admins have no
  /// pharmacies row, so without this they'd look identical to an orphaned
  /// registration and get pushed into the KYC recovery flow.
  admin,
}

/// Single source of truth for "who is signed in and what may they do".
///
/// This exists because the app previously had *no* auth gate of any kind:
///
///   * `GoRouter` had no `redirect`, so every route was reachable by deep
///     link with no session at all.
///   * Splash and login both went straight to `/home` on any session,
///     without ever looking at `pharmacies.status` — so the entire KYC
///     approval process was bypassed by signing out and back in. A
///     `pending`, `rejected` or even `suspended` pharmacy got the full
///     marketplace.
///   * Nothing listened to `onAuthStateChange`, so an expired or revoked
///     session just produced errors on every screen instead of returning
///     the user to sign-in.
///
/// It's a [ChangeNotifier] rather than a pure Riverpod provider so the
/// router can take it directly as `refreshListenable` without the
/// provider-container-before-router bootstrap problem.
class SessionController extends ChangeNotifier {
  SessionState _state = SessionState.unknown;
  StreamSubscription<AuthState>? _sub;
  int _resolveToken = 0;

  SessionState get state => _state;

  bool get isSignedIn => switch (_state) {
        SessionState.unknown || SessionState.signedOut => false,
        _ => true,
      };

  /// Called once from `main()` after Supabase is initialized.
  void start() {
    _sub ??= supabase.auth.onAuthStateChange.listen((event) {
      switch (event.event) {
        case AuthChangeEvent.signedOut:
          _set(SessionState.signedOut);
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.initialSession:
        case AuthChangeEvent.userUpdated:
          unawaited(refresh());
        case AuthChangeEvent.tokenRefreshed:
          // Nothing to re-resolve; the role/status can't change here and
          // re-querying on every refresh would be a request every hour.
          break;
        case AuthChangeEvent.passwordRecovery:
          // Handled by the recovery listener in main(); don't disturb
          // routing mid-flow.
          break;
        default:
          unawaited(refresh());
      }
    });
    unawaited(refresh());
  }

  /// Re-resolves the session's role/status from the server.
  ///
  /// Uses `get_my_status()` (migration 0034) rather than selecting from
  /// `pharmacies` directly: an account with no pharmacy row would get an
  /// empty result from a plain select, which is indistinguishable from a
  /// network failure at the call site. The RPC returns an explicit 'none'.
  Future<void> refresh() async {
    final token = ++_resolveToken;

    if (supabase.auth.currentSession == null) {
      if (token == _resolveToken) _set(SessionState.signedOut);
      return;
    }

    try {
      final rows = await supabase.rpc('get_my_status');
      if (token != _resolveToken) return;

      final list = rows as List<dynamic>;
      if (list.isEmpty) {
        _set(SessionState.needsRegistration);
        return;
      }
      final row = list.first as Map<String, dynamic>;
      final role = row['role'] as String?;
      final status = row['status'] as String?;

      _set(switch (role) {
        'admin' => SessionState.admin,
        'pharmacy' => switch (status) {
            'approved' => SessionState.approved,
            'rejected' => SessionState.rejected,
            'suspended' => SessionState.suspended,
            _ => SessionState.pending,
          },
        'anonymous' => SessionState.signedOut,
        _ => SessionState.needsRegistration,
      });
    } catch (error, stack) {
      if (token != _resolveToken) return;
      // A network failure must not silently downgrade a signed-in user to
      // "needs registration" and dump them into the KYC flow. Hold the
      // previous decision if we had one; otherwise stay on the splash.
      debugPrint('SessionController.refresh failed: $error\n$stack');
      if (_state == SessionState.unknown) {
        _set(SessionState.unknown);
      }
    }
  }

  void _set(SessionState next) {
    if (_state == next) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// App-wide singleton. The router needs it at construction time, before any
/// ProviderScope exists.
final sessionController = SessionController();

/// Riverpod view of the same object. It's a plain [Provider] exposing the
/// notifier (rather than `ChangeNotifierProvider`, which moved to
/// riverpod's legacy import in 3.x) — widgets that need to rebuild on a
/// session change wrap in a `ListenableBuilder`.
final sessionControllerProvider = Provider<SessionController>((ref) => sessionController);
