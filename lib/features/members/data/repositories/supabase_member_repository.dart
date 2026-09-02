import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/trip_invitation.dart';
import '../../domain/entities/trip_member.dart';
import '../../domain/repositories/member_repository.dart';

class SupabaseMemberRepository implements MemberRepository {
  SupabaseMemberRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<TripMember>> getMembers(String tripId) async {
    final memberRows = await _client
        .from('trip_members')
        .select()
        .eq('trip_id', tripId)
        .isFilter('deleted_at', null)
        .order('joined_at');
    if (memberRows.isEmpty) return const [];

    final userIds = memberRows
        .map((row) => row['user_id'] as String)
        .toList(growable: false);
    final profileRows =
        await _client.from('profiles').select().inFilter('id', userIds);
    final profiles = {
      for (final profile in profileRows) profile['id'] as String: profile,
    };

    return memberRows.map((row) {
      final userId = row['user_id'] as String;
      final profile = profiles[userId];
      return TripMember(
        userId: userId,
        tripId: row['trip_id'] as String,
        displayName: profile?['display_name'] as String? ?? 'Trip member',
        avatarUrl: profile?['avatar_url'] as String?,
        role: TripMemberRole.fromDatabase(row['role'] as String),
        joinedAt: DateTime.parse(row['joined_at'] as String),
      );
    }).toList(growable: false);
  }

  @override
  Future<List<TripInvitation>> getInvitations(String tripId) async {
    final rows = await _client
        .from('trip_invitations')
        .select()
        .eq('trip_id', tripId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return rows.map(_mapInvitation).toList(growable: false);
  }

  @override
  Future<TripInvitation> createInvitation(String tripId) async {
    final row = await _client.rpc(
      'create_trip_invitation',
      params: {'target_trip_id': tripId},
    ).single();
    return _mapInvitation(row);
  }

  @override
  Future<void> revokeInvitation(String invitationId) => _client.rpc(
        'revoke_trip_invitation',
        params: {'target_invitation_id': invitationId},
      );

  @override
  Future<void> removeMember({
    required String tripId,
    required String userId,
  }) =>
      _client.rpc(
        'remove_trip_member',
        params: {'target_trip_id': tripId, 'target_user_id': userId},
      );

  @override
  Future<InvitationPreview> previewInvitation(String code) async {
    final row = await _client.rpc(
      'preview_trip_invitation',
      params: {'submitted_code': _normalizeCode(code)},
    ).maybeSingle();
    if (row == null) throw const InvalidInvitationException();
    return InvitationPreview(
      tripId: row['trip_id'] as String,
      destination: row['destination'] as String,
      ownerName: row['owner_name'] as String,
      startDate: DateTime.parse(row['start_date'] as String),
      endDate: DateTime.parse(row['end_date'] as String),
      expiresAt: DateTime.parse(row['expires_at'] as String),
    );
  }

  @override
  Future<String> acceptInvitation(String code) async {
    final result = await _client.rpc(
      'accept_trip_invitation',
      params: {'submitted_code': _normalizeCode(code)},
    );
    return result as String;
  }

  @override
  Future<void> declineInvitation(String code) => _client.rpc(
        'decline_trip_invitation',
        params: {'submitted_code': _normalizeCode(code)},
      );

  @override
  Future<void> leaveTrip(String tripId) => _client.rpc(
        'leave_trip',
        params: {'target_trip_id': tripId},
      );

  @override
  Future<void> transferOwnership({
    required String tripId,
    required String newOwnerId,
  }) =>
      _client.rpc(
        'transfer_trip_ownership',
        params: {
          'target_trip_id': tripId,
          'new_owner_id': newOwnerId,
        },
      );

  static String _normalizeCode(String code) => code.trim().toUpperCase();

  static TripInvitation _mapInvitation(Map<String, dynamic> row) {
    final expiresAt = DateTime.parse(row['expires_at'] as String);
    var status = InvitationStatus.fromDatabase(row['status'] as String);
    if (status == InvitationStatus.pending &&
        expiresAt.isBefore(DateTime.now())) {
      status = InvitationStatus.expired;
    }
    return TripInvitation(
      id: row['id'] as String,
      tripId: row['trip_id'] as String,
      inviteCode: row['invite_code'] as String,
      status: status,
      expiresAt: expiresAt,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}

class InvalidInvitationException implements Exception {
  const InvalidInvitationException();

  @override
  String toString() => 'This invitation is invalid, expired, or already used.';
}
