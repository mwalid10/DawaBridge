/// Row shape of the `notifications` table, read directly by the client
/// (RLS restricts rows to `pharmacy_id = auth.uid()` — see
/// 0007_deals_chat_notifications.sql). Named `AppNotification` to avoid
/// colliding with Flutter's own `Notification` widget type.
class AppNotification {
  final String id;
  final String kind;
  final String title;
  final String? body;
  final String? dealId;
  final String? listingId;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.dealId,
    required this.listingId,
    required this.read,
    required this.createdAt,
  });

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      kind: kind,
      title: title,
      body: body,
      dealId: dealId,
      listingId: listingId,
      read: read ?? this.read,
      createdAt: createdAt,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      kind: json['kind'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      dealId: json['deal_id'] as String?,
      listingId: json['listing_id'] as String?,
      read: json['read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
