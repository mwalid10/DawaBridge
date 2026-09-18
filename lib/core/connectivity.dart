import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether the app can currently reach the backend.
///
/// The app had no notion of being offline at all. Every failure looked the
/// same as every other failure, several screens had no way to retry, and a
/// cold start with no network hung on the splash forever because the
/// session could never resolve.
///
/// Two signals, deliberately:
///
///   * `connectivity_plus` reports the *network interface* — wifi, mobile,
///     none. It's instant and cheap, but it is NOT reachability: a handset
///     attached to a captive-portal wifi, or on a mobile connection with no
///     data left, reports "connected" while nothing can actually get out.
///     So a positive reading here is treated as "worth retrying", never as
///     "we are definitely online".
///   * Real request outcomes, reported through [reportSuccess] and
///     [reportFailure]. These are ground truth, because they're the thing
///     we actually care about.
///
/// The result is that [isOffline] only ever goes true because something
/// genuinely failed, and the interface signal is used to decide when to
/// try again.
class ConnectivityController extends ChangeNotifier {
  ConnectivityController({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool _offline = false;
  bool _hasInterface = true;

  /// True once a request has actually failed for network reasons, or the
  /// device reports no interface at all.
  bool get isOffline => _offline || !_hasInterface;

  /// Fires when the device regains an interface after losing one, or when a
  /// request succeeds after a failure. Controllers listen to this to refetch
  /// whatever they missed — Realtime inserts that happened while the socket
  /// was down are simply gone, so a refetch is the only way to catch up.
  final _reconnected = StreamController<void>.broadcast();
  Stream<void> get onReconnected => _reconnected.stream;

  void start() {
    _sub ??= _connectivity.onConnectivityChanged.listen(_onInterfaceChanged);
    unawaited(_primeInterfaceState());
  }

  Future<void> _primeInterfaceState() async {
    try {
      _onInterfaceChanged(await _connectivity.checkConnectivity());
    } catch (error) {
      // Platform channel unavailable (desktop, tests). Assume an interface
      // exists and let real request outcomes decide.
      debugPrint('Connectivity check failed, assuming online: $error');
    }
  }

  void _onInterfaceChanged(List<ConnectivityResult> results) {
    final had = _hasInterface;
    _hasInterface = results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none);

    if (_hasInterface && !had) {
      // Interface came back. Not proof we can reach anything, but it's the
      // right moment to find out.
      _offline = false;
      notifyListeners();
      _reconnected.add(null);
      return;
    }
    if (had != _hasInterface) notifyListeners();
  }

  /// Call after any request that completed, network-wise.
  void reportSuccess() {
    if (!_offline) return;
    _offline = false;
    notifyListeners();
    _reconnected.add(null);
  }

  /// Call when a request failed for a reason that looks like connectivity.
  void reportFailure() {
    if (_offline) return;
    _offline = true;
    notifyListeners();
  }

  /// Whether [error] looks like a connectivity problem rather than a
  /// server-side rejection. Kept next to the controller so the definition
  /// can't drift from `AppError`'s.
  static bool looksOffline(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('clientexception') ||
        text.contains('failed host lookup') ||
        text.contains('connection closed') ||
        text.contains('connection refused') ||
        text.contains('connection reset') ||
        text.contains('network is unreachable') ||
        text.contains('software caused connection abort') ||
        error is TimeoutException;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _reconnected.close();
    super.dispose();
  }
}

/// App-wide singleton — the router and `main()` need it before any
/// ProviderScope exists, same as [sessionController].
final connectivityController = ConnectivityController();

final connectivityProvider = Provider<ConnectivityController>((ref) => connectivityController);
