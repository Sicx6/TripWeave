class ActivityComment {
  const ActivityComment({
    required this.id,
    required this.proposalId,
    required this.userId,
    required this.authorName,
    required this.body,
    required this.createdAt,
    required this.version,
    this.authorAvatarUrl,
  });

  final String id;
  final String proposalId;
  final String userId;
  final String authorName;
  final String? authorAvatarUrl;
  final String body;
  final DateTime createdAt;
  final int version;
}
