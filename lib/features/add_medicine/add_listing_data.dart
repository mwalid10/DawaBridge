import '../drugs/drug.dart';
import '../listings/listing_summary.dart';

/// Form state for the Add Medicine screen, mirroring KycData's
/// copyWith style. Quantity is deliberately not stored here — it's a plain
/// text field validated locally in the screen at submit time, same as the
/// KYC steps' text fields.
class AddListingData {
  final Drug? drug;
  final ListingType? type;
  final DateTime? expiryDate;
  final List<String> acceptedAlternatives;
  final String? photoPath;
  final double? price;
  final double? discountPrice;
  final String? description;

  const AddListingData({
    this.drug,
    this.type,
    this.expiryDate,
    this.acceptedAlternatives = const [],
    this.photoPath,
    this.price,
    this.discountPrice,
    this.description,
  });

  AddListingData copyWith({
    Drug? drug,
    ListingType? type,
    DateTime? expiryDate,
    List<String>? acceptedAlternatives,
    String? photoPath,
    double? price,
    double? discountPrice,
    String? description,
  }) {
    return AddListingData(
      drug: drug ?? this.drug,
      type: type ?? this.type,
      expiryDate: expiryDate ?? this.expiryDate,
      acceptedAlternatives: acceptedAlternatives ?? this.acceptedAlternatives,
      photoPath: photoPath ?? this.photoPath,
      price: price ?? this.price,
      discountPrice: discountPrice ?? this.discountPrice,
      description: description ?? this.description,
    );
  }

  bool get isControlledBlocked => drug?.isControlled == true;

  bool get hasRequiredSelections => drug != null && !isControlledBlocked && type != null && expiryDate != null;
}
