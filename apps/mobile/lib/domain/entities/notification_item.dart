/// A notification delivered to the user (spec Section 5.13).
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    this.title,
    this.body,
    required this.read,
    required this.sentAt,
  });

  final String id;
  final String type; // trip_reminder | budget_warning | trip_status | marketing
  final String? title;
  final String? body;
  final bool read;
  final DateTime? sentAt;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String?,
      body: json['body'] as String?,
      read: json['read'] as bool? ?? false,
      sentAt: DateTime.tryParse(json['sent_at'] as String? ?? ''),
    );
  }
}
