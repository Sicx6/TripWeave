import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/device_activity_location_repository.dart';
import '../../domain/entities/map_place.dart';
import '../../domain/repositories/activity_location_repository.dart';

final activityLocationRepositoryProvider =
    Provider<ActivityLocationRepository>((ref) {
  return DeviceActivityLocationRepository();
});

final activityLocationControllerProvider =
    AsyncNotifierProvider<ActivityLocationController, List<MapPlace>>(
  ActivityLocationController.new,
);

class ActivityLocationController extends AsyncNotifier<List<MapPlace>> {
  ActivityLocationRepository get _repository =>
      ref.read(activityLocationRepositoryProvider);

  @override
  Future<List<MapPlace>> build() async => const [];

  Future<void> search(String query) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.searchPlaces(query));
  }

  Future<MapPlace?> useCurrentLocation() async {
    state = const AsyncLoading();
    try {
      final place = await _repository.getCurrentLocation();
      state = const AsyncData([]);
      return place;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  void clear() => state = const AsyncData([]);
}
