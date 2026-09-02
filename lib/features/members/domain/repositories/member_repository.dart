import '../entities/trip_invitation.dart';
import '../entities/trip_member.dart';

abstract interface class MemberRepository {
  Future<List<TripMember>> getMembers(String tripId);
  Future<List<TripInvitation>> getInvitations(String tripId);
  Future<TripInvitation> createInvitation(String tripId);
  Future<void> revokeInvitation(String invitationId);
  Future<void> removeMember({required String tripId, required String userId});
  Future<InvitationPreview> previewInvitation(String code);
  Future<String> acceptInvitation(String code);
  Future<void> declineInvitation(String code);
  Future<void> leaveTrip(String tripId);
  Future<void> transferOwnership({
    required String tripId,
    required String newOwnerId,
  });
}
