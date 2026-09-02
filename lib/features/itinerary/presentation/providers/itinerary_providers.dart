import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../activities/presentation/providers/activity_providers.dart';
import '../../data/repositories/supabase_itinerary_repository.dart';
import '../../domain/entities/itinerary_item.dart';
import '../../domain/repositories/itinerary_repository.dart';

final itineraryRepositoryProvider = Provider<ItineraryRepository>((ref) {
  return SupabaseItineraryRepository(Supabase.instance.client);
});

final itineraryListProvider = FutureProvider.autoDispose
    .family<List<ItineraryItem>, String>((ref, tripId) {
  return ref.watch(itineraryRepositoryProvider).getItems(tripId);
});

final itineraryControllerProvider =
    AsyncNotifierProvider<ItineraryController, void>(ItineraryController.new);

class ItineraryController extends AsyncNotifier<void> {
  ItineraryRepository get _repository => ref.read(itineraryRepositoryProvider);

  @override
  Future<void> build() async {}

  Future<bool> addProposal({
    required String tripId,
    required String proposalId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final success = await _run(
      tripId,
      () => _repository.addApprovedProposal(
        tripId: tripId,
        proposalId: proposalId,
        startAt: startAt,
        endAt: endAt,
      ),
    );
    if (success) ref.invalidate(activityListProvider(tripId));
    return success;
  }

  Future<bool> reorder(String tripId, List<String> orderedIds) => _run(
      tripId,
      () => _repository.reorder(
            tripId: tripId,
            orderedItemIds: orderedIds,
          ));

  Future<bool> changeStatus(
    ItineraryItem item,
    ItineraryItemStatus status,
  ) =>
      _run(
        item.tripId,
        () => _repository.changeStatus(item: item, status: status),
      );

  Future<bool> _run(
    String tripId,
    Future<Object?> Function() operation,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(operation);
    if (!state.hasError) ref.invalidate(itineraryListProvider(tripId));
    return !state.hasError;
  }
}
