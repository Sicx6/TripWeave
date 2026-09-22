import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/map_place.dart';
import '../providers/activity_location_providers.dart';

class ActivityMapSelection {
  const ActivityMapSelection({required this.point, this.displayName});

  final LatLng point;
  final String? displayName;
}

class ActivityLocationPickerScreen extends ConsumerStatefulWidget {
  const ActivityLocationPickerScreen({this.initialLocation, super.key});

  final LatLng? initialLocation;

  @override
  ConsumerState<ActivityLocationPickerScreen> createState() =>
      _ActivityLocationPickerScreenState();
}

class _ActivityLocationPickerScreenState
    extends ConsumerState<ActivityLocationPickerScreen> {
  static const _defaultLocation = LatLng(3.1390, 101.6869);
  final _mapController = MapController();
  final _searchController = TextEditingController();
  late LatLng _selectedLocation;
  String? _selectedDisplayName;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation ?? _defaultLocation;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(activityLocationControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Choose activity location')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 13,
              onTap: (_, point) {
                ref.read(activityLocationControllerProvider.notifier).clear();
                setState(() {
                  _selectedLocation = point;
                  _selectedDisplayName = null;
                  _hasSearched = false;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.tripweave',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 52,
                    height: 52,
                    child: Icon(
                      Icons.location_pin,
                      size: 52,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Column(
              children: [
                Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(16),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _search,
                    decoration: InputDecoration(
                      hintText: 'Search a place or address',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: search.isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              tooltip: 'Search',
                              onPressed: () => _search(_searchController.text),
                              icon: const Icon(Icons.arrow_forward_rounded),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                    ),
                  ),
                ),
                if (search.hasError)
                  _SearchMessage(message: _friendlyError(search.error)),
                if (_hasSearched &&
                    !search.isLoading &&
                    !search.hasError &&
                    search.valueOrNull?.isEmpty == true)
                  const _SearchMessage(
                    message: 'No matching places found. Try a broader name.',
                  ),
                if (search.valueOrNull?.isNotEmpty == true)
                  _SearchResults(
                    places: search.valueOrNull!,
                    onSelected: _selectPlace,
                  ),
              ],
            ),
          ),
          Positioned(
            right: 18,
            bottom: 94,
            child: FloatingActionButton.small(
              heroTag: 'activity-current-location',
              tooltip: 'Use my location',
              onPressed: search.isLoading ? null : _useCurrentLocation,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  ActivityMapSelection(
                    point: _selectedLocation,
                    displayName: _selectedDisplayName,
                  ),
                ),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Use this location'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _search(String query) async {
    FocusScope.of(context).unfocus();
    setState(() => _hasSearched = true);
    await ref.read(activityLocationControllerProvider.notifier).search(query);
  }

  void _selectPlace(MapPlace place) {
    final point = LatLng(place.latitude, place.longitude);
    setState(() {
      _selectedLocation = point;
      _selectedDisplayName = place.name;
      _searchController.text = place.name;
      _hasSearched = false;
    });
    _mapController.move(point, 16);
    ref.read(activityLocationControllerProvider.notifier).clear();
  }

  Future<void> _useCurrentLocation() async {
    final place = await ref
        .read(activityLocationControllerProvider.notifier)
        .useCurrentLocation();
    if (!mounted) return;
    if (place == null) {
      final error = ref.read(activityLocationControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
      ref.read(activityLocationControllerProvider.notifier).clear();
      return;
    }
    final point = LatLng(place.latitude, place.longitude);
    setState(() {
      _selectedLocation = point;
      _selectedDisplayName = null;
      _hasSearched = false;
    });
    _mapController.move(point, 16);
  }

  static String _friendlyError(Object? error) {
    final text = error?.toString() ?? 'Unable to find that location.';
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.places, required this.onSelected});

  final List<MapPlace> places;
  final ValueChanged<MapPlace> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: places.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, index) {
            final place = places[index];
            return ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(place.name, maxLines: 2),
              onTap: () => onSelected(place),
            );
          },
        ),
      ),
    );
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message),
      ),
    );
  }
}
