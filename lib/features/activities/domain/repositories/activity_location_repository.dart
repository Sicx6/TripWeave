import '../entities/map_place.dart';

abstract interface class ActivityLocationRepository {
  Future<List<MapPlace>> searchPlaces(String query);
  Future<MapPlace> getCurrentLocation();
}
