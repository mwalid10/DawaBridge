/// Row shape of the `messages` table, read directly by the client (RLS
/// restricts rows to deal participants — see 0007_deals_chat_notifications.sql).
class Message {
  final String id;
  final String dealId;
  final String senderId;
  final String body;
  final String? attachmentPath;
  final double? locationLat;
  final double? locationLng;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.dealId,
    required this.senderId,
    required this.body,
    this.attachmentPath,
    this.locationLat,
    this.locationLng,
    required this.createdAt,
  });

  bool get isLocation => locationLat != null && locationLng != null;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      dealId: json['deal_id'] as String,
      senderId: json['sender_id'] as String,
      body: json['body'] as String,
      attachmentPath: json['attachment_path'] as String?,
      locationLat: (json['location_lat'] as num?)?.toDouble(),
      locationLng: (json['location_lng'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
