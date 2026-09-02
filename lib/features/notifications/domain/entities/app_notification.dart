class AppNotification {
  const AppNotification({
    required this.id,
    required this.tripId,
    required this.title,
    required this.message,
    required this.createdAt,
    this.proposalId,
    this.actorName,
    this.readAt,
  });

  final String id;
  final String tripId;
  final String? proposalId;
  final String title;
  final String message;
  final String? actorName;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;
}
