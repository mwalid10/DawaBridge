import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';

/// Registers this device's FCM token against the signed-in pharmacy so the
/// admin broadcast-notification edge function can push to it (see
/// 0033_device_push_tokens.sql). Watched once from AppShell, which only
/// ever builds post-login, so `build()` runs with a real session already in
/// place — no need to react to auth-state changes here.
class PushTokenController extends AsyncNotifier<void> {
  StreamSubscription<String>? _refreshSub;

  @override
  Future<void> build() async {
    ref.onDispose(() => _refreshSub?.cancel());

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

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
