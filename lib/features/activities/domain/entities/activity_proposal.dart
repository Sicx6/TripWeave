enum ProposalStatus {
  proposed,
  voting,
  approved,
  rejected,
  scheduled,
  completed,
  cancelled;

  String get label => switch (this) {
        ProposalStatus.proposed => 'Proposed',
        ProposalStatus.voting => 'Voting',
        ProposalStatus.approved => 'Approved',
        ProposalStatus.rejected => 'Rejected',
        ProposalStatus.scheduled => 'Scheduled',
        ProposalStatus.completed => 'Completed',
        ProposalStatus.cancelled => 'Cancelled',
      };

  static ProposalStatus fromDatabase(String value) {
    return ProposalStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ProposalStatus.proposed,
    );
  }
}

class ActivityProposal {
  const ActivityProposal({
    required this.id,
    required this.tripId,
    required this.proposedBy,
    required this.title,
    required this.category,
    required this.submittedByName,
    required this.location,
    required this.proposedAt,
    required this.estimatedCostCents,
    required this.description,
    required this.status,
    required this.yesVotes,
    required this.noVotes,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.imageUrl,
    this.customCategory,
    this.submittedByAvatarUrl,
    this.currentUserVote,
  });

  final String id;
  final String tripId;
  final String proposedBy;
  final String title;
  final String category;
  final String? customCategory;
  final String submittedByName;
  final String? submittedByAvatarUrl;
  final String location;
  final DateTime proposedAt;
  final int estimatedCostCents;
  final String description;
  final String? imageUrl;
  final ProposalStatus status;
  final int yesVotes;
  final int noVotes;
  final bool? currentUserVote;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  int get totalVotes => yesVotes + noVotes;

  String get displayCategory =>
      category == 'Custom' && customCategory?.trim().isNotEmpty == true
          ? customCategory!.trim()
          : category;

  String get formattedCost {
    final whole = estimatedCostCents ~/ 100;
    final cents = (estimatedCostCents % 100).toString().padLeft(2, '0');
    return 'RM $whole.$cents';
  }
}
