import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';

/// Turns whatever came back from Supabase into a sentence a pharmacist can
/// read, in their own language.
///
/// Before this, failures were surfaced by interpolating the raw exception
/// straight into the UI — `error.toString()` in the OTP screen, and l10n
/// strings like `chatCouldntSendAttachment(error)` that took the exception
/// object as a placeholder. So a pharmacist hitting a perfectly ordinary
/// condition ("someone else already reserved this") saw an untranslated
/// `PostgrestException(message: Listing is no longer available, code: P0001
/// ...)`. The deals controller even documented it: "callers show
/// `error.toString()` to the user".
///
/// The server-side RPCs now raise stable SCREAMING_SNAKE codes instead of
/// English prose (see migrations 0035-0040), which is what this maps. An
/// unrecognised code falls back to a generic message rather than leaking
/// internals — the raw error still goes to the console for debugging.
class AppError {
  AppError._();

  /// Pulls the stable code out of whatever exception type this is.
  static String? codeOf(Object error) {
    final raw = switch (error) {
      PostgrestException e => e.message,
      AuthException e => e.message,
      StorageException e => e.message,
      _ => error.toString(),
    };

    // Postgres wraps `raise exception 'FOO'` as a message that contains the
    // literal; match the first all-caps token so we're not thrown by
    // surrounding formatting.
    final match = RegExp(r'\b([A-Z][A-Z0-9_]{3,})\b').firstMatch(raw);
    return match?.group(1);
  }

  /// Human-readable, localized message for [error].
  static String message(AppLocalizations l10n, Object error) {
    if (error is AuthException) {
      final m = error.message.toLowerCase();
      if (m.contains('invalid login') || m.contains('invalid credentials')) {
        return l10n.errorInvalidCredentials;
      }
      if (m.contains('email not confirmed')) return l10n.errorEmailNotConfirmed;
      if (m.contains('already registered') || m.contains('already been registered')) {
        return l10n.errorEmailAlreadyRegistered;
      }
      if (m.contains('token has expired') || m.contains('invalid token') || m.contains('otp')) {
        return l10n.errorOtpInvalid;
      }
      if (m.contains('rate limit') || m.contains('too many')) return l10n.errorRateLimited;
      if (m.contains('password')) return l10n.errorWeakPassword;
    }

    if (error is StorageException) {
      final m = error.message.toLowerCase();
      if (m.contains('exceeded the maximum allowed size') || m.contains('too large')) {
        return l10n.errorFileTooLarge;
      }
      if (m.contains('mime') || m.contains('not supported')) return l10n.errorFileType;
    }

    return switch (codeOf(error)) {
      'AUTH_REQUIRED' => l10n.errorAuthRequired,
      'PHARMACY_NOT_APPROVED' => l10n.errorNotApproved,
      'ACCOUNT_IS_ADMIN' => l10n.errorAccountIsAdmin,
      'ACCOUNT_HAS_ACTIVE_DEALS' => l10n.errorAccountHasActiveDeals,
      'ACCOUNT_HAS_OPEN_DISPUTES' => l10n.errorAccountHasOpenDisputes,
      'LISTING_NOT_FOUND' => l10n.errorListingNotFound,
      'LISTING_OWN' => l10n.errorListingOwn,
      'LISTING_UNAVAILABLE' => l10n.errorListingUnavailable,
      'LISTING_EXPIRED' => l10n.errorListingExpired,
      'LISTING_EXPIRY_IN_PAST' => l10n.errorListingExpiryInPast,
      'LISTING_NOT_OWNER' => l10n.errorListingNotOwner,
      'LISTING_NOT_EDITABLE' => l10n.errorListingNotEditable,
      'LISTING_FROZEN' => l10n.errorListingNotEditable,
      'LISTING_RESERVED_NO_EDIT' => l10n.errorListingReservedNoEdit,
      'LISTING_HAS_ACTIVE_DEAL' => l10n.errorListingHasActiveDeal,
      'LISTING_QUANTITY_INVALID' => l10n.errorQuantityInvalid,
      'LISTING_PRICE_INVALID' => l10n.errorPriceInvalid,
      'LISTING_DISCOUNT_INVALID' => l10n.errorDiscountInvalid,
      'LISTING_CONTROLLED_SUBSTANCE' => l10n.errorControlledSubstance,
      'DEAL_NOT_FOUND' => l10n.errorDealNotFound,
      'DEAL_NOT_PARTICIPANT' => l10n.errorDealNotParticipant,
      'DEAL_ALREADY_OPEN' => l10n.errorDealAlreadyOpen,
      'DEAL_SELLER_ONLY' => l10n.errorDealSellerOnly,
      'DEAL_NOT_PENDING' => l10n.errorDealNotPending,
      'DEAL_NOT_ACTIVE' => l10n.errorDealNotActive,
      'DEAL_UNKNOWN_ACTION' => l10n.errorGeneric,
      'DISPUTE_ALREADY_OPEN' => l10n.errorDisputeAlreadyOpen,
      'DISPUTE_REASON_REQUIRED' => l10n.errorDisputeReasonRequired,
      'RATING_INVALID_STARS' => l10n.errorRatingInvalidStars,
      'RATING_DEAL_NOT_COMPLETED' => l10n.errorRatingDealNotCompleted,
      'DRUG_NAME_REQUIRED' => l10n.errorDrugNameRequired,
      'DRUG_NAME_TOO_LONG' => l10n.errorDrugNameTooLong,
      'PHARMACY_NAME_REQUIRED' => l10n.errorPharmacyNameRequired,
      'GOVERNORATE_REQUIRED' => l10n.errorGovernorateRequired,
      'LOCATION_REQUIRED' => l10n.errorLocationRequired,
      'LOCATION_OUT_OF_BOUNDS' => l10n.errorLocationOutOfBounds,
      'LICENSE_REQUIRED' => l10n.errorLicenseRequired,
      'FILE_TOO_LARGE' => l10n.errorFileTooLarge,
      // Deal actions are online-only by design — see OfflineActionException.
      'OFFLINE_ACTION' => l10n.offlineActionUnavailable,
      _ => _networkOrGeneric(l10n, error),
    };
  }

  static String _networkOrGeneric(AppLocalizations l10n, Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('connection closed') ||
        text.contains('timeout') ||
        text.contains('network is unreachable')) {
      return l10n.errorNetwork;
    }
    return l10n.errorGeneric;
  }
}
