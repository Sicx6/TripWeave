import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/map_place.dart';
import '../../domain/repositories/activity_location_repository.dart';

class DeviceActivityLocationRepository implements ActivityLocationRepository {
  DeviceActivityLocationRepository({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<List<MapPlace>> searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];
    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      {'q': trimmed, 'format': 'jsonv2', 'limit': '5'},
    );
    final response = await _client.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'TripWeave/1.0 (collaborative trip planner)',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Place search is unavailable. Try again shortly.');
    }
    final values = jsonDecode(response.body) as List<dynamic>;
    return values.map((value) {
      final row = value as Map<String, dynamic>;
      return MapPlace(
        name: row['display_name'] as String,
        latitude: double.parse(row['lat'] as String),
        longitude: double.parse(row['lon'] as String),
      );
    }).toList(growable: false);
  }

  @override
  Future<MapPlace> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Turn on location services and try again.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Location permission was not granted.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is blocked. Enable it in device settings.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return MapPlace(
      name: 'Current location',
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}
