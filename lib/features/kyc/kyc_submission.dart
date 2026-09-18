import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/file_utils.dart';
import '../../core/session.dart';
import '../../core/supabase_client.dart';
import 'kyc_data.dart';

/// Creates (or repairs) the caller's `pharmacies` row.
///
/// The old flow lived inline in `otp_verification_screen.dart` and ran
/// three unprotected steps back to back: verify the OTP — which creates and
/// signs in the auth user — then upload the licence, then insert the
/// pharmacy row. Nothing was transactional and nothing rolled back, so a
/// failure in either of the last two steps left a confirmed auth account
/// with no pharmacy attached. There was no recovery path at all: signing up
/// again failed on "User already registered", the plain `upload()` (not
/// upsert) meant a retry 409'd on the object that had already landed, and
/// the splash screen sent the session to `/home` where every query keyed on
/// the pharmacy row threw. One such account was already in the live
/// database.
///
/// Both problems are fixed here:
///
///   * `upsert: true` makes the licence upload safe to repeat.
///   * `complete_my_registration()` (migration 0039) is idempotent — it
///     returns the existing status instead of erroring if the row is
///     already there — so the whole function is safe to retry, and the
///     recovery screen can call exactly the same code path as a
///     first-time registration.
Future<void> submitPharmacyRegistration(KycData data) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) throw StateError('AUTH_REQUIRED');

  final localPath = data.licenseFilePath;
  if (localPath == null) throw StateError('LICENSE_REQUIRED');

  final storagePath = '$uid/license.${fileExtension(localPath)}';

  await supabase.storage.from('licenses').upload(
        storagePath,
        File(localPath),
        fileOptions: const FileOptions(upsert: true),
      );

  await supabase.rpc('complete_my_registration', params: {
    'p_name': data.pharmacyName,
    'p_governorate': data.governorate,
    'p_area': data.area,
    'p_address_text': data.addressText,
    'p_lat': data.pinLocation?.latitude,
    'p_lng': data.pinLocation?.longitude,
    'p_license_url': storagePath,
    'p_license_expiry': data.licenseExpiry?.toIso8601String().split('T').first,
  });

  // Let the router move the user on rather than navigating by hand.
  await sessionController.refresh();
}
