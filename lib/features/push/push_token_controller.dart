import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import '../../main.dart' show firebaseReady;

/// Registers this device's FCM token against the signed-in pharmacy so the
/// broadcast-notification edge function can push to it (see
/// 0033_device_push_tokens.sql).
class PushTokenController extends AsyncNotifier<void> {
  StreamSubscription<String>? _refreshSub;

  @override
  Future<void> build() async {
    ref.onDispose(() => _refreshSub?.cancel());

    // Firebase is optional at runtime now — on iOS there's no
    // GoogleService-Info.plist yet, and touching the messaging SDK when
    // initializeApp() failed throws.
    if (!firebaseReady) return;

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    final settings = await FirebaseMessaging.instance.requestPermission();
    // Only `denied` was checked before, so `notDetermined` (which iOS can
    // return if the prompt is dismissed without an answer) fell through and
    // registered a token that will never receive anything.
    final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!granted) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _upsert(uid, token);

    _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      final currentUid = supabase.auth.currentUser?.id;
      if (currentUid != null) _upsert(currentUid, newToken);
    });
  }

  Future<void> _upsert(String pharmacyId, String token) async {
    await supabase.from('device_push_tokens').upsert({
      'pharmacy_id': pharmacyId,
      'token': token,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'token');
  }
}

final pushTokenControllerProvider = AsyncNotifierProvider<PushTokenController, void>(PushTokenController.new);

/// Unregisters this device before signing out.
///
/// Nothing did this before: the token row survived sign-out, so the device
/// kept receiving pushes addressed to the pharmacy that had logged out —
/// including new-message notifications for deals the next person to pick up
/// the phone had nothing to do with. Call this *before* `auth.signOut()`,
/// while the session can still satisfy the owner-scoped RLS policy on
/// `device_push_tokens`.
Future<void> unregisterPushToken() async {
  if (!firebaseReady) return;
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await supabase.from('device_push_tokens').delete().eq('token', token);
  } catch (error) {
    // Best effort: never block sign-out on this.
    debugPrint('Failed to unregister push token: $error');
  }
}
