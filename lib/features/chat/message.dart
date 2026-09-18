/// Row shape of the `messages` table, read through `get_messages()` and the
/// Realtime channel (RLS restricts rows to deal participants — see
/// 0007_deals_chat_notifications.sql).
class Message {
  final String id;
  final String dealId;

  /// Null for system messages — see [isSystem].
  final String? senderId;
  final String body;
  final String? attachmentPath;
  final double? locationLat;
  final double? locationLng;

  /// Written by `respond_to_deal()` to record a lifecycle change
  /// ("Request accepted", "Deal cancelled").
  ///
  /// These used to be posted with `sender_id` set to whoever clicked, so the
  /// thread rendered them as an ordinary chat bubble *from that person* —
  /// the other party saw "Deal cancelled." as though it had been typed at
  /// them. Migration 0035 moved them to `sender_id = null` + this flag so
  /// they render as neutral system lines.
  final bool isSystem;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.dealId,
    required this.senderId,
    required this.body,
    this.attachmentPath,
    this.locationLat,
    this.locationLng,
    this.isSystem = false,
    required this.createdAt,
  });

  bool get isLocation => locationLat != null && locationLng != null;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      dealId: json['deal_id'] as String,
      senderId: json['sender_id'] as String?,
      body: json['body'] as String,
      attachmentPath: json['attachment_path'] as String?,
      locationLat: (json['location_lat'] as num?)?.toDouble(),
      locationLng: (json['location_lng'] as num?)?.toDouble(),
      isSystem: json['is_system'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
