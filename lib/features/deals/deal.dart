import '../listings/listing_summary.dart';

/// Row shape returned by the `get_my_deals`/`get_deal_detail` RPCs — a
/// security-definer join of deals + listings + drugs + the counterpart
/// pharmacy's safe (name-only) columns, same contract as ListingSummary.
class Deal {
  final String id;
  final String listingId;
  final String drugTradeName;
  final ListingType listingType;
  final ListingState state;
  final bool isSeller;
  final String counterpartId;
  final String counterpartName;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime createdAt;

  const Deal({
    required this.id,
    required this.listingId,
    required this.drugTradeName,
    required this.listingType,
    required this.state,
    required this.isSeller,
    required this.counterpartId,
    required this.counterpartName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.createdAt,
  });

  factory Deal.fromJson(Map<String, dynamic> json) {
    return Deal(
      id: json['deal_id'] as String,
      listingId: json['listing_id'] as String,
      drugTradeName: json['drug_trade_name'] as String,
      listingType: ListingType.fromString(json['listing_type'] as String),
      state: ListingState.fromString(json['deal_state'] as String),
      isSeller: json['is_seller'] as bool,
      counterpartId: json['counterpart_id'] as String,
      counterpartName: json['counterpart_name'] as String,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] == null ? null : DateTime.parse(json['last_message_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Row shape returned by `get_deal_detail` — like [Deal] but with the
/// listing's quantity instead of a last-message preview, for the chat
/// thread header.
class DealDetail {
  final String id;
  final String listingId;
  final String drugTradeName;
  final ListingType listingType;
  final int quantity;
  final ListingState state;
  final bool isSeller;
  final String counterpartId;
  final String counterpartName;
  final DateTime createdAt;

  const DealDetail({
    required this.id,
    required this.listingId,
    required this.drugTradeName,
    required this.listingType,
    required this.quantity,
    required this.state,
    required this.isSeller,
    required this.counterpartId,
    required this.counterpartName,
    required this.createdAt,
  });

  factory DealDetail.fromJson(Map<String, dynamic> json) {
    return DealDetail(
      id: json['deal_id'] as String,
      listingId: json['listing_id'] as String,
      drugTradeName: json['drug_trade_name'] as String,
      listingType: ListingType.fromString(json['listing_type'] as String),
      quantity: json['quantity'] as int,
      state: ListingState.fromString(json['deal_state'] as String),
      isSeller: json['is_seller'] as bool,
      counterpartId: json['counterpart_id'] as String,
      counterpartName: json['counterpart_name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
