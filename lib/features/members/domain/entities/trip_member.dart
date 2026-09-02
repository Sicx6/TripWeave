enum TripMemberRole {
  owner,
  member;

  String get label => this == owner ? 'Owner' : 'Member';

  static TripMemberRole fromDatabase(String value) =>
      value == 'owner' ? TripMemberRole.owner : TripMemberRole.member;
}

class TripMember {
  const TripMember({
    required this.userId,
    required this.tripId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
    this.avatarUrl,
  });

  final String userId;
  final String tripId;
  final String displayName;
  final String? avatarUrl;
  final TripMemberRole role;
  final DateTime joinedAt;
}
