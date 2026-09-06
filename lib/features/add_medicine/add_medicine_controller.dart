import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import '../drugs/drug.dart';
import '../listings/listing_summary.dart';
import 'add_listing_data.dart';

class AddMedicineController extends Notifier<AddListingData> {
  String? _lastLoggedControlledDrugId;

  @override
  AddListingData build() => const AddListingData();

  void selectDrug(Drug drug) {
    state = AddListingData(
      drug: drug,
      type: state.type,
      expiryDate: state.expiryDate,
      photoPath: state.photoPath,
      price: state.price,
      discountPrice: state.discountPrice,
      description: state.description,
    );
    if (drug.isControlled && _lastLoggedControlledDrugId != drug.id) {
      _lastLoggedControlledDrugId = drug.id;
      // Fire-and-forget: a failed compliance log must never block showing
      // the block message itself.
      supabase.rpc('log_compliance_flag', params: {
        'p_drug_id': drug.id,
        'p_kind': 'controlled_substance_listing_attempt',
      }).catchError((_) => null);
    }
  }

  /// Resolves a catalog pick (or a freely typed name with no catalog
  /// match) to a real `drugs` row via find_or_create_drug — see
  /// 0022_drug_catalog.sql. Concentration/company/pharmaceutical_form are
  /// optional: a fully custom name just creates a bare `drugs` row with
  /// only a trade name, same as picking one that already exists resolves
  /// straight to it.
  Future<void> selectDrugByName(
    String tradeName, {
    String? concentration,
    String? company,
    String? pharmaceuticalForm,
  }) async {
    final rows = await supabase.rpc('find_or_create_drug', params: {
      'p_trade_name': tradeName,
      'p_concentration': concentration,
      'p_company': company,
      'p_pharmaceutical_form': pharmaceuticalForm,
    });
    final row = (rows as List<dynamic>).first as Map<String, dynamic>;
    selectDrug(Drug.fromJson(row));
  }

  void clearDrug() {
    state = AddListingData(
      type: state.type,
      expiryDate: state.expiryDate,
      photoPath: state.photoPath,
      price: state.price,
      discountPrice: state.discountPrice,
      description: state.description,
    );
  }

  void selectType(ListingType type) {
    state = state.copyWith(
      type: type,
      acceptedAlternatives: type == ListingType.barter ? state.acceptedAlternatives : const [],
    );
  }

  void setExpiry(DateTime expiry) => state = state.copyWith(expiryDate: expiry);

  void toggleAlternative(String drugId) {
    final current = state.acceptedAlternatives;
    final next = current.contains(drugId) ? current.where((id) => id != drugId).toList() : [...current, drugId];
    state = state.copyWith(acceptedAlternatives: next);
  }

  void setPhotoPath(String path) => state = state.copyWith(photoPath: path);

  void clearPhoto() {
    state = AddListingData(
      drug: state.drug,
      type: state.type,
      expiryDate: state.expiryDate,
      acceptedAlternatives: state.acceptedAlternatives,
      price: state.price,
      discountPrice: state.discountPrice,
      description: state.description,
    );
  }

  void setPrice(double? price) => state = AddListingData(
        drug: state.drug,
        type: state.type,
        expiryDate: state.expiryDate,
        acceptedAlternatives: state.acceptedAlternatives,
        photoPath: state.photoPath,
        price: price,
        discountPrice: state.discountPrice,
        description: state.description,
      );

  void setDiscountPrice(double? discountPrice) => state = AddListingData(
        drug: state.drug,
        type: state.type,
        expiryDate: state.expiryDate,
        acceptedAlternatives: state.acceptedAlternatives,
        photoPath: state.photoPath,
        price: state.price,
        discountPrice: discountPrice,
        description: state.description,
      );

  void setDescription(String? description) => state = AddListingData(
        drug: state.drug,
        type: state.type,
        expiryDate: state.expiryDate,
        acceptedAlternatives: state.acceptedAlternatives,
        photoPath: state.photoPath,
        price: state.price,
        discountPrice: state.discountPrice,
        description: description,
      );

  void reset() => state = const AddListingData();

  Future<void> submit({required int quantity}) async {
    final data = state;
    final uid = supabase.auth.currentUser!.id;

    String? photoUrl;
    if (data.photoPath != null) {
      final ext = data.photoPath!.split('.').last;
      final path = '$uid/${DateTime.now().microsecondsSinceEpoch}.$ext';
      await supabase.storage.from('medicine-photos').upload(path, File(data.photoPath!));
      photoUrl = supabase.storage.from('medicine-photos').getPublicUrl(path);
    }

    await supabase.from('listings').insert({
      'pharmacy_id': uid,
      'drug_id': data.drug!.id,
      'type': data.type!.name,
      'quantity': quantity,
      'expiry_date': data.expiryDate!.toIso8601String().split('T').first,
      'accepted_alternatives': data.type == ListingType.barter ? data.acceptedAlternatives : <String>[],
      'photo_url': photoUrl,
      'price': data.price,
      'discount_price': data.discountPrice,
      'description': data.description,
    });
  }
}

final addMedicineControllerProvider = NotifierProvider<AddMedicineController, AddListingData>(AddMedicineController.new);
