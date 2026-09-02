import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/supabase_activity_repository.dart';
import '../../domain/entities/activity_proposal.dart';
import '../../domain/entities/activity_comment.dart';
import '../../domain/repositories/activity_repository.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return SupabaseActivityRepository(Supabase.instance.client);
});

final activityListProvider = FutureProvider.autoDispose
    .family<List<ActivityProposal>, String>((ref, tripId) {
  return ref.watch(activityRepositoryProvider).getProposals(tripId);
});

final activityCommentListProvider = FutureProvider.autoDispose
    .family<List<ActivityComment>, String>((ref, proposalId) {
  return ref.watch(activityRepositoryProvider).getComments(proposalId);
});

final activityControllerProvider =
    AsyncNotifierProvider<ActivityController, void>(ActivityController.new);

class ActivityController extends AsyncNotifier<void> {
  ActivityRepository get _repository => ref.read(activityRepositoryProvider);

  @override
  Future<void> build() async {}

  Future<bool> createProposal({
    required String tripId,
    required ActivityDraft draft,
  }) =>
      _run(
        tripId,
        () => _repository.createProposal(tripId: tripId, draft: draft),
      );

  Future<bool> vote({
    required String tripId,
    required String proposalId,
    required bool support,
  }) =>
      _run(
        tripId,
        () => _repository.vote(proposalId: proposalId, support: support),
      );

  Future<bool> decide({
    required ActivityProposal proposal,
    required ProposalStatus status,
  }) =>
      _run(
        proposal.tripId,
        () => _repository.decideProposal(proposal: proposal, status: status),
      );

  Future<bool> addComment({
    required String proposalId,
    required String body,
  }) =>
      _runComments(
        proposalId,
        () => _repository.addComment(proposalId: proposalId, body: body),
      );

  Future<bool> deleteComment({
    required String proposalId,
    required String commentId,
  }) =>
      _runComments(
        proposalId,
        () => _repository.deleteComment(commentId),
      );

  Future<bool> _runComments(
    String proposalId,
    Future<Object?> Function() operation,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(operation);
    if (!state.hasError) {
      ref.invalidate(activityCommentListProvider(proposalId));
    }
    return !state.hasError;
  }

  Future<bool> _run(
    String tripId,
    Future<Object?> Function() operation,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(operation);
    if (!state.hasError) ref.invalidate(activityListProvider(tripId));
    return !state.hasError;
  }
}
