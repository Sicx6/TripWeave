import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/supabase_trip_repository.dart';
import '../../domain/entities/trip.dart';
import '../../domain/repositories/trip_repository.dart';

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return SupabaseTripRepository(Supabase.instance.client);
});

final tripListProvider = FutureProvider.autoDispose<List<Trip>>((ref) {
  return ref.watch(tripRepositoryProvider).getTrips();
});

final tripControllerProvider =
    AsyncNotifierProvider<TripController, void>(TripController.new);

class TripController extends AsyncNotifier<void> {
  TripRepository get _repository => ref.read(tripRepositoryProvider);

  @override
  Future<void> build() async {}

  Future<bool> createTrip(TripDraft draft) =>
      _run(() => _repository.createTrip(draft));

  Future<bool> updateTrip({required Trip trip, required TripDraft draft}) =>
      _run(() => _repository.updateTrip(trip: trip, draft: draft));

  Future<bool> changeStatus(Trip trip, TripStatus status) => _run(
        () => _repository.changeStatus(
          tripId: trip.id,
          expectedVersion: trip.version,
          status: status,
        ),
      );

  Future<bool> _run(Future<Object?> Function() operation) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(operation);
    if (!state.hasError) ref.invalidate(tripListProvider);
    return !state.hasError;
  }
}
