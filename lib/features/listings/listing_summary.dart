import '../../l10n/app_localizations.dart';

enum ListingType {
  sell,
  buy,
  barter;

  static ListingType fromString(String value) => ListingType.values.byName(value);

  String label(AppLocalizations l10n) => switch (this) {
        ListingType.sell => l10n.listingTypeSell,
        ListingType.buy => l10n.listingTypeBuy,
        ListingType.barter => l10n.listingTypeExchange,
      };
}

enum ListingState {
  available,
  reserved,
  completed,
  cancelled;

  static ListingState fromString(String value) => ListingState.values.byName(value);

  String label(AppLocalizations l10n) => switch (this) {
        ListingState.available => l10n.listingStateAvailable,
        ListingState.reserved => l10n.listingStateReserved,
        ListingState.completed => l10n.listingStateCompleted,
        ListingState.cancelled => l10n.listingStateCancelled,
      };
}

/// Row shape returned by the `search_listings`/`get_listing_detail` RPCs —
/// a security-definer join of listings + drugs + a safe subset of
/// pharmacies (never email/address_text/lat/lng/license_url).
class ListingSummary {
  final String id;
  final String drugId;
  final String tradeName;
  final String? activeIngredient;
  final String? concentration;
  final String? company;
  final String? pharmaceuticalForm;
  final bool isControlled;
  final ListingType type;
  final int quantity;
  final double? price;
  final double? discountPrice;
  final String? description;
  final DateTime expiryDate;
  final ListingState state;
  final List<String> acceptedAlternatives;
  final String? photoUrl;
  final DateTime createdAt;
  final String pharmacyId;
  final String pharmacyName;
  final String governorate;
  final String area;
  final double? pharmacyLat;
  final double? pharmacyLng;
  final double? distanceKm;

  const ListingSummary({
    required this.id,
    required this.drugId,
    required this.tradeName,
    this.activeIngredient,
    this.concentration,
    this.company,
    this.pharmaceuticalForm,
    required this.isControlled,
    required this.type,
    required this.quantity,
    this.price,
    this.discountPrice,
    this.description,
    required this.expiryDate,
    required this.state,
    required this.acceptedAlternatives,
    required this.photoUrl,
    required this.createdAt,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.governorate,
    required this.area,
    this.pharmacyLat,
    this.pharmacyLng,
    required this.distanceKm,
  });

  factory ListingSummary.fromJson(Map<String, dynamic> json) {
    return ListingSummary(
      id: json['listing_id'] as String,
      drugId: json['drug_id'] as String,
      tradeName: json['trade_name'] as String,
      activeIngredient: json['active_ingredient'] as String?,
      concentration: json['concentration'] as String?,
      company: json['company'] as String?,
      pharmaceuticalForm: json['pharmaceutical_form'] as String?,
      isControlled: json['is_controlled'] as bool,
      type: ListingType.fromString(json['listing_type'] as String),
      quantity: json['quantity'] as int,
      price: (json['price'] as num?)?.toDouble(),
      discountPrice: (json['discount_price'] as num?)?.toDouble(),
      description: json['description'] as String?,
      expiryDate: DateTime.parse(json['expiry_date'] as String),
      state: ListingState.fromString(json['listing_state'] as String),
      acceptedAlternatives: (json['accepted_alternatives'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      photoUrl: json['photo_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      pharmacyId: json['pharmacy_id'] as String,
      pharmacyName: json['pharmacy_name'] as String,
      governorate: json['governorate'] as String,
      area: json['area'] as String,
      pharmacyLat: (json['pharmacy_lat'] as num?)?.toDouble(),
      pharmacyLng: (json['pharmacy_lng'] as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }
}
