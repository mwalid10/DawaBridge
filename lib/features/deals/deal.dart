import '../listings/listing_summary.dart';

/// Lifecycle of a deal, as `deal_status` in the database.
///
/// Deals used to reuse the `listing_state` enum
/// ('available'/'reserved'/'completed'/'cancelled'), which allowed the
/// meaningless state "deal: available" and had no way to express "the buyer
/// has asked and the seller hasn't answered yet" — because there *was* no
/// asking step. `request_listing()` reserved the listing outright, so any
/// buyer could lock any seller's stock by tapping a button. See migration
/// 0035 for the rebuilt flow.
enum DealState {
  /// Buyer has requested; seller hasn't responded. The listing is still
  /// available and other buyers can queue behind this one.
  pending,

  /// Seller accepted. The listing is now reserved for this buyer.
  accepted,

  /// Seller said no, or accepted someone else's request, or the 48h
  /// response window lapsed.
  declined,
  completed,
  cancelled;

  static DealState fromString(String value) => switch (value) {
        'pending' => DealState.pending,
        'accepted' => DealState.accepted,
        'declined' => DealState.declined,
        'completed' => DealState.completed,
        _ => DealState.cancelled,
      };

  /// Still in play — the thread can be acted on.
  bool get isLive => this == DealState.pending || this == DealState.accepted;

  /// The seller is the only one who can accept, decline or complete.
  bool get awaitsSeller => this == DealState.pending;
}

/// Row shape returned by the `get_my_deals`/`get_deal_detail` RPCs — a
/// security-definer join of deals + listings + drugs + the counterpart
/// pharmacy's safe (name-only) columns, same contract as ListingSummary.
class Deal {
  final String id;
  final String listingId;
  final String drugTradeName;
  final ListingType listingType;
  final DealState state;
  final bool isSeller;
  final String counterpartId;
  final String counterpartName;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  /// When this deal lapses: the seller's response deadline while pending,
  /// the reservation deadline once accepted. Null in a terminal state.
  final DateTime? expiresAt;
  final int unreadCount;
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
    required this.expiresAt,
    required this.unreadCount,
    required this.createdAt,
  });

  factory Deal.fromJson(Map<String, dynamic> json) {
    return Deal(
      id: json['deal_id'] as String,
      listingId: json['listing_id'] as String,
      drugTradeName: json['drug_trade_name'] as String,
      listingType: ListingType.fromString(json['listing_type'] as String),
      state: DealState.fromString(json['deal_state'] as String),
      isSeller: json['is_seller'] as bool,
      counterpartId: json['counterpart_id'] as String,
      counterpartName: json['counterpart_name'] as String,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] == null ? null : DateTime.parse(json['last_message_at'] as String),
      expiresAt: json['expires_at'] == null ? null : DateTime.parse(json['expires_at'] as String),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
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
  final DealState state;
  final bool isSeller;
  final String counterpartId;
  final String counterpartName;
  final DateTime? expiresAt;
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
    required this.expiresAt,
    required this.createdAt,
  });

  factory DealDetail.fromJson(Map<String, dynamic> json) {
    return DealDetail(
      id: json['deal_id'] as String,
      listingId: json['listing_id'] as String,
      drugTradeName: json['drug_trade_name'] as String,
      listingType: ListingType.fromString(json['listing_type'] as String),
      quantity: json['quantity'] as int,
      state: DealState.fromString(json['deal_state'] as String),
      isSeller: json['is_seller'] as bool,
      counterpartId: json['counterpart_id'] as String,
      counterpartName: json['counterpart_name'] as String,
      expiresAt: json['expires_at'] == null ? null : DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
