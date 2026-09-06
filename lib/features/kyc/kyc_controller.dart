import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'kyc_data.dart';

class KycController extends Notifier<KycData> {
  @override
  KycData build() => const KycData();

  void updatePharmacyDetails({required String name, required String email}) {
    state = state.copyWith(pharmacyName: name, email: email);
  }

  void updateAddress({
    required String governorate,
    required String area,
    required String addressText,
    required LatLng pinLocation,
  }) {
    state = state.copyWith(
      governorate: governorate,
      area: area,
      addressText: addressText,
      pinLocation: pinLocation,
    );
  }

  void updateLicense({required String filePath, required DateTime expiry}) {
    state = state.copyWith(licenseFilePath: filePath, licenseExpiry: expiry);
  }

  void updatePassword(String password) {
    state = state.copyWith(password: password);
  }

  void reset() {
    state = const KycData();
  }
}

final kycControllerProvider = NotifierProvider<KycController, KycData>(KycController.new);
