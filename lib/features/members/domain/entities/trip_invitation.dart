enum InvitationStatus {
  pending,
  accepted,
  declined,
  expired,
  revoked;

  String get label => switch (this) {
        InvitationStatus.pending => 'Pending',
        InvitationStatus.accepted => 'Accepted',
        InvitationStatus.declined => 'Declined',
        InvitationStatus.expired => 'Expired',
        InvitationStatus.revoked => 'Revoked',
      };

  static InvitationStatus fromDatabase(String value) {
    return InvitationStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => InvitationStatus.pending,
    );
  }
}

class TripInvitation {
  const TripInvitation({
    required this.id,
    required this.tripId,
    required this.inviteCode,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
  });

  final String id;
  final String tripId;
  final String inviteCode;
  final InvitationStatus status;
  final DateTime expiresAt;
  final DateTime createdAt;

  bool get isUsable =>
      status == InvitationStatus.pending && expiresAt.isAfter(DateTime.now());
}

class InvitationPreview {
  const InvitationPreview({
    required this.tripId,
    required this.destination,
    required this.ownerName,
    required this.startDate,
    required this.endDate,
    required this.expiresAt,
  });

  final String tripId;
  final String destination;
  final String ownerName;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime expiresAt;
}
