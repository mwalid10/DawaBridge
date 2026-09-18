import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/file_utils.dart';
import '../../core/rpc.dart';
import '../../core/supabase_client.dart';
import '../drugs/drug.dart';
import '../listings/listing_summary.dart';
import 'add_listing_data.dart';

/// Recognised by AppError via its message code.
class PhotoTooLargeException implements Exception {
  const PhotoTooLargeException();
  @override
  String toString() => 'FILE_TOO_LARGE';
}

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
    final row = await rpcSingle(
      'find_or_create_drug',
      params: {
        'p_trade_name': tradeName,
        'p_concentration': concentration,
        'p_company': company,
        'p_pharmaceutical_form': pharmaceuticalForm,
      },
      notFoundLabel: 'drug',
    );
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
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('AUTH_REQUIRED');

    // These were all bare `!` derefs. Submit is gated on
    // `hasRequiredSelections` in the UI, but a null here crashed with an
    // unhelpful TypeError instead of a message.
    final drug = data.drug;
    final type = data.type;
    final expiry = data.expiryDate;
    if (drug == null || type == null || expiry == null) {
      throw StateError('LISTING_INCOMPLETE');
    }

    String? photoUrl;
    String? photoPath;
    final localPhoto = data.photoPath;
    if (localPhoto != null) {
      final size = await fileSizeBytes(localPhoto);
      if (size != null && size > maxMedicinePhotoBytes) {
        throw const PhotoTooLargeException();
      }
      // `split('.').last` returned the whole path for an extensionless
      // file, producing an unusable storage key — see `fileExtension`.
      photoPath = '$uid/${DateTime.now().microsecondsSinceEpoch}.${fileExtension(localPhoto)}';
      await supabase.storage.from('medicine-photos').upload(photoPath, File(localPhoto));
      photoUrl = supabase.storage.from('medicine-photos').getPublicUrl(photoPath);
    }

    try {
      await supabase.from('listings').insert({
        'pharmacy_id': uid,
        'drug_id': drug.id,
        'type': type.name,
        'quantity': quantity,
        'expiry_date': expiry.toIso8601String().split('T').first,
        'accepted_alternatives': type == ListingType.barter ? data.acceptedAlternatives : <String>[],
        'photo_url': photoUrl,
        'price': data.price,
        'discount_price': data.discountPrice,
        'description': data.description,
      });
    } catch (_) {
      // The photo is uploaded before the insert, so any insert failure —
      // a rejected expiry date, the controlled-substance block from
      // migration 0037, a dropped connection — used to strand the file in
      // the bucket with nothing pointing at it. Nothing could ever remove
      // it either: `medicine-photos` had no DELETE policy until 0040.
      if (photoPath != null) {
        await supabase.storage
            .from('medicine-photos')
            .remove([photoPath]).catchError((_) => <FileObject>[]);
      }
      rethrow;
    }
  }
}

final addMedicineControllerProvider = NotifierProvider<AddMedicineController, AddListingData>(AddMedicineController.new);
