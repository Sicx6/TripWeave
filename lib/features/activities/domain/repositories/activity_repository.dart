import '../entities/activity_proposal.dart';
import '../entities/activity_comment.dart';

class ActivityDraft {
  const ActivityDraft({
    required this.title,
    required this.category,
    required this.location,
    required this.proposedAt,
    required this.estimatedCostCents,
    required this.description,
    this.imagePath,
    this.customCategory,
  });

  final String title;
  final String category;
  final String? customCategory;
  final String location;
  final DateTime proposedAt;
  final int estimatedCostCents;
  final String description;
  final String? imagePath;
}

abstract interface class ActivityRepository {
  Future<List<ActivityProposal>> getProposals(String tripId);

  Future<ActivityProposal> createProposal({
    required String tripId,
    required ActivityDraft draft,
  });

  Future<void> vote({required String proposalId, required bool support});

  Future<void> decideProposal({
    required ActivityProposal proposal,
    required ProposalStatus status,
  });

  Future<List<ActivityComment>> getComments(String proposalId);
  Future<void> addComment({required String proposalId, required String body});
  Future<void> deleteComment(String commentId);
}
