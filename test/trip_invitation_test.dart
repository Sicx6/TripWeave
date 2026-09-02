import 'package:flutter_test/flutter_test.dart';
import 'package:tripweave/features/members/domain/entities/trip_invitation.dart';

void main() {
  test('pending future invitation is usable', () {
    final invitation = TripInvitation(
      id: 'invite-1',
      tripId: 'trip-1',
      inviteCode: 'A1B2C3D4E5',
      status: InvitationStatus.pending,
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      createdAt: DateTime.now(),
    );

    expect(invitation.isUsable, isTrue);
  });

  test('expired invitation is not usable', () {
    final invitation = TripInvitation(
      id: 'invite-2',
      tripId: 'trip-1',
      inviteCode: 'ABCDE12345',
      status: InvitationStatus.pending,
      expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
    );

    expect(invitation.isUsable, isFalse);
  });
}
