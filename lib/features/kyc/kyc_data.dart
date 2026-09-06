import 'package:latlong2/latlong.dart';

/// Form state carried across the 4-step KYC wizard.
///
/// `pinLocation`, `licenseExpiry` and the license file exist specifically
/// because the original spec relied on free-text addresses (unreliable
/// geocoding) and never captured a license expiry date at all — both are
/// mandatory here, not optional add-ons, so the wizard can't be completed
/// without them.
class KycData {
  final String pharmacyName;
  final String email;
  final String governorate;
  final String area;
  final String addressText;
  final LatLng? pinLocation;
  final String? licenseFilePath;
  final DateTime? licenseExpiry;
  final String password;

  const KycData({
    this.pharmacyName = '',
    this.email = '',
    this.governorate = '',
    this.area = '',
    this.addressText = '',
    this.pinLocation,
    this.licenseFilePath,
    this.licenseExpiry,
    this.password = '',
  });

  KycData copyWith({
    String? pharmacyName,
    String? email,
    String? governorate,
    String? area,
    String? addressText,
    LatLng? pinLocation,
    String? licenseFilePath,
    DateTime? licenseExpiry,
    String? password,
  }) {
    return KycData(
      pharmacyName: pharmacyName ?? this.pharmacyName,
      email: email ?? this.email,
      governorate: governorate ?? this.governorate,
      area: area ?? this.area,
      addressText: addressText ?? this.addressText,
      pinLocation: pinLocation ?? this.pinLocation,
      licenseFilePath: licenseFilePath ?? this.licenseFilePath,
      licenseExpiry: licenseExpiry ?? this.licenseExpiry,
      password: password ?? this.password,
    );
  }

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get step1Valid => pharmacyName.trim().length >= 3 && _emailPattern.hasMatch(email);

  bool get step2Valid => governorate.isNotEmpty && area.trim().isNotEmpty && addressText.trim().isNotEmpty && pinLocation != null;

  bool get step3Valid =>
      licenseFilePath != null &&
      licenseExpiry != null &&
      licenseExpiry!.isAfter(DateTime.now());

  bool passwordValid(String confirm) {
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    return password.length >= 8 && hasUpper && hasNumber && hasSpecial && password == confirm;
  }
}
