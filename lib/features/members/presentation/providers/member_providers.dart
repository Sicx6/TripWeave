import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../trips/presentation/providers/trip_providers.dart';
import '../../data/repositories/supabase_member_repository.dart';
import '../../domain/entities/trip_invitation.dart';
import '../../domain/entities/trip_member.dart';
import '../../domain/repositories/member_repository.dart';

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return SupabaseMemberRepository(Supabase.instance.client);
});

final memberListProvider =
    FutureProvider.autoDispose.family<List<TripMember>, String>((ref, tripId) {
  return ref.watch(memberRepositoryProvider).getMembers(tripId);
});

final invitationListProvider = FutureProvider.autoDispose
    .family<List<TripInvitation>, String>((ref, tripId) {
  return ref.watch(memberRepositoryProvider).getInvitations(tripId);
});

final memberControllerProvider =
    AsyncNotifierProvider<MemberController, void>(MemberController.new);

class MemberController extends AsyncNotifier<void> {
  MemberRepository get _repository => ref.read(memberRepositoryProvider);

  @override
  Future<void> build() async {}

  Future<TripInvitation?> createInvitation(String tripId) async {
    state = const AsyncLoading();
    TripInvitation? invitation;
    state = await AsyncValue.guard(() async {
      invitation = await _repository.createInvitation(tripId);
    });
    if (!state.hasError) ref.invalidate(invitationListProvider(tripId));
    return invitation;
  }

  Future<bool> revokeInvitation({
    required String tripId,
    required String invitationId,
  }) =>
      _run(
        () => _repository.revokeInvitation(invitationId),
        onSuccess: () => ref.invalidate(invitationListProvider(tripId)),
      );

  Future<bool> removeMember({
    required String tripId,
    required String userId,
  }) =>
      _run(
        () => _repository.removeMember(tripId: tripId, userId: userId),
        onSuccess: () => ref.invalidate(memberListProvider(tripId)),
      );

  Future<bool> leaveTrip(String tripId) => _run(
        () => _repository.leaveTrip(tripId),
        onSuccess: () {
          ref.invalidate(memberListProvider(tripId));
          ref.invalidate(tripListProvider);
        },
      );

  Future<bool> transferOwnership({
    required String tripId,
    required String newOwnerId,
  }) =>
      _run(
        () => _repository.transferOwnership(
          tripId: tripId,
          newOwnerId: newOwnerId,
        ),
        onSuccess: () {
          ref.invalidate(memberListProvider(tripId));
          ref.invalidate(tripListProvider);
        },
      );

  Future<bool> _run(
    Future<Object?> Function() operation, {
    required void Function() onSuccess,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(operation);
    if (!state.hasError) onSuccess();
    return !state.hasError;
  }
}

final joinTripControllerProvider =
    AsyncNotifierProvider<JoinTripController, InvitationPreview?>(
        JoinTripController.new);

class JoinTripController extends AsyncNotifier<InvitationPreview?> {
  MemberRepository get _repository => ref.read(memberRepositoryProvider);

  @override
  Future<InvitationPreview?> build() async => null;

  Future<bool> preview(String code) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.previewInvitation(code));
    return !state.hasError;
  }

  Future<bool> accept(String code) async {
    final preview = state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.acceptInvitation(code);
      return preview;
    });
    if (!state.hasError) ref.invalidate(tripListProvider);
    return !state.hasError;
  }

  Future<bool> decline(String code) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.declineInvitation(code);
      return null;
    });
    return !state.hasError;
  }

  void clear() => state = const AsyncData(null);
}
