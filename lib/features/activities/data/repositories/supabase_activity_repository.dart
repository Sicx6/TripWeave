import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/activity_proposal.dart';
import '../../domain/entities/activity_comment.dart';
import '../../domain/repositories/activity_repository.dart';

class SupabaseActivityRepository implements ActivityRepository {
  SupabaseActivityRepository(this._client);

  final SupabaseClient _client;
  static const _uuid = Uuid();

  @override
  Future<List<ActivityProposal>> getProposals(String tripId) async {
    final proposalRows = await _client
        .from('activity_proposals')
        .select()
        .eq('trip_id', tripId)
        .isFilter('deleted_at', null)
        .order('proposed_at');
    if (proposalRows.isEmpty) return const [];

    final proposalIds =
        proposalRows.map((row) => row['id'] as String).toList(growable: false);
    final voteRows = await _client
        .from('activity_votes')
        .select('proposal_id, user_id, support')
        .inFilter('proposal_id', proposalIds)
        .isFilter('deleted_at', null);
    final proposerIds = proposalRows
        .map((row) => row['proposed_by'] as String)
        .toSet()
        .toList(growable: false);
    final profileRows =
        await _client.from('profiles').select().inFilter('id', proposerIds);
    final profiles = {
      for (final profile in profileRows) profile['id'] as String: profile,
    };
    final userId = _client.auth.currentUser?.id;

    return proposalRows.map((row) {
      final id = row['id'] as String;
      final votes = voteRows.where((vote) => vote['proposal_id'] == id);
      final ownVotes = votes.where((vote) => vote['user_id'] == userId);
      final profile = profiles[row['proposed_by'] as String];
      return _mapProposal(
        row,
        submittedByName: profile?['display_name'] as String? ?? 'Trip member',
        submittedByAvatarUrl: profile?['avatar_url'] as String?,
        yesVotes: votes.where((vote) => vote['support'] == true).length,
        noVotes: votes.where((vote) => vote['support'] == false).length,
        currentUserVote:
            ownVotes.isEmpty ? null : ownVotes.first['support'] as bool,
      );
    }).toList(growable: false);
  }

  @override
  Future<ActivityProposal> createProposal({
    required String tripId,
    required ActivityDraft draft,
  }) async {
    final userId = _requireUserId();
    final proposalId = _uuid.v4();
    final imageUrl = await _uploadImage(
      tripId: tripId,
      proposalId: proposalId,
      imagePath: draft.imagePath,
    );
    final row = await _client
        .from('activity_proposals')
        .insert({
          'id': proposalId,
          'trip_id': tripId,
          'proposed_by': userId,
          'title': draft.title.trim(),
          'category': draft.category,
          'custom_category': draft.customCategory?.trim(),
          'location': draft.location.trim(),
          'proposed_at': draft.proposedAt.toUtc().toIso8601String(),
          'estimated_cost': _moneyValue(draft.estimatedCostCents),
          'description': draft.description.trim(),
          'image_url': imageUrl,
          'status': ProposalStatus.voting.name,
        })
        .select()
        .single();
    final metadata = _client.auth.currentUser?.userMetadata;
    return _mapProposal(
      row,
      submittedByName: metadata?['display_name'] as String? ?? 'Trip member',
      submittedByAvatarUrl: metadata?['avatar_url'] as String?,
    );
  }

  @override
  Future<void> vote({
    required String proposalId,
    required bool support,
  }) async {
    await _client.from('activity_votes').upsert(
      {
        'proposal_id': proposalId,
        'user_id': _requireUserId(),
        'support': support,
      },
      onConflict: 'proposal_id,user_id',
    );
  }

  @override
  Future<void> decideProposal({
    required ActivityProposal proposal,
    required ProposalStatus status,
  }) async {
    final row = await _client
        .from('activity_proposals')
        .update({'status': status.name})
        .eq('id', proposal.id)
        .eq('version', proposal.version)
        .select('id')
        .maybeSingle();
    if (row == null) throw const ActivityConflictException();
  }

  @override
  Future<List<ActivityComment>> getComments(String proposalId) async {
    final rows = await _client
        .from('activity_comments')
        .select()
        .eq('proposal_id', proposalId)
        .isFilter('deleted_at', null)
        .order('created_at');
    if (rows.isEmpty) return const [];

    final userIds = rows
        .map((row) => row['user_id'] as String)
        .toSet()
        .toList(growable: false);
    final profileRows =
        await _client.from('profiles').select().inFilter('id', userIds);
    final profiles = {
      for (final profile in profileRows) profile['id'] as String: profile,
    };
    return rows.map((row) {
      final profile = profiles[row['user_id'] as String];
      return ActivityComment(
        id: row['id'] as String,
        proposalId: row['proposal_id'] as String,
        userId: row['user_id'] as String,
        authorName: profile?['display_name'] as String? ?? 'Trip member',
        authorAvatarUrl: profile?['avatar_url'] as String?,
        body: row['body'] as String,
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        version: row['version'] as int,
      );
    }).toList(growable: false);
  }

  @override
  Future<void> addComment({
    required String proposalId,
    required String body,
  }) =>
      _client.from('activity_comments').insert({
        'id': _uuid.v4(),
        'proposal_id': proposalId,
        'user_id': _requireUserId(),
        'body': body.trim(),
      });

  @override
  Future<void> deleteComment(String commentId) => _client
      .from('activity_comments')
      .update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq(
          'id', commentId);

  String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('You are not signed in.');
    return userId;
  }

  Future<String?> _uploadImage({
    required String tripId,
    required String proposalId,
    required String? imagePath,
  }) async {
    if (imagePath == null) return null;
    final extension = imagePath.split('.').last.toLowerCase();
    final path = '$tripId/$proposalId/image.$extension';
    await _client.storage.from('activity-images').upload(
          path,
          File(imagePath),
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('activity-images').getPublicUrl(path);
  }

  static String _moneyValue(int cents) => (cents / 100).toStringAsFixed(2);

  static ActivityProposal _mapProposal(
    Map<String, dynamic> row, {
    int yesVotes = 0,
    int noVotes = 0,
    bool? currentUserVote,
    String submittedByName = 'Trip member',
    String? submittedByAvatarUrl,
  }) {
    final rawCost = row['estimated_cost'];
    final cost =
        rawCost is num ? rawCost.toString() : rawCost as String? ?? '0';
    return ActivityProposal(
      id: row['id'] as String,
      tripId: row['trip_id'] as String,
      proposedBy: row['proposed_by'] as String,
      title: row['title'] as String,
      category: row['category'] as String,
      customCategory: row['custom_category'] as String?,
      submittedByName: submittedByName,
      submittedByAvatarUrl: submittedByAvatarUrl,
      location: row['location'] as String,
      proposedAt: DateTime.parse(row['proposed_at'] as String).toLocal(),
      estimatedCostCents: (num.parse(cost) * 100).round(),
      description: row['description'] as String,
      imageUrl: row['image_url'] as String?,
      status: ProposalStatus.fromDatabase(row['status'] as String),
      yesVotes: yesVotes,
      noVotes: noVotes,
      currentUserVote: currentUserVote,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      version: row['version'] as int,
    );
  }
}

class ActivityConflictException implements Exception {
  const ActivityConflictException();

  @override
  String toString() =>
      'This suggestion changed on another device. Refresh and try again.';
}
