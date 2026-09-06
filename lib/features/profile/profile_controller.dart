import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import 'pharmacy_profile.dart';
import 'rating_summary.dart';

class PharmacyProfileController extends AsyncNotifier<PharmacyProfile> {
  @override
  Future<PharmacyProfile> build() async {
    final uid = supabase.auth.currentUser!.id;
    final row = await supabase.from('pharmacies').select().eq('id', uid).single();
    return PharmacyProfile.fromJson(row);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}

final pharmacyProfileControllerProvider =
    AsyncNotifierProvider<PharmacyProfileController, PharmacyProfile>(PharmacyProfileController.new);

class RatingSummaryController extends AsyncNotifier<RatingSummary> {
  @override
  Future<RatingSummary> build() async {
    final rows = await supabase.rpc('get_my_rating_summary');
    final row = (rows as List<dynamic>).first as Map<String, dynamic>;
    return RatingSummary.fromJson(row);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}

final ratingSummaryControllerProvider =
    AsyncNotifierProvider<RatingSummaryController, RatingSummary>(RatingSummaryController.new);
