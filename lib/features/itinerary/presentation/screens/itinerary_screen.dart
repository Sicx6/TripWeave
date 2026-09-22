import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../activities/domain/entities/activity_proposal.dart';
import '../../../activities/presentation/providers/activity_providers.dart';
import '../../../trips/domain/entities/trip.dart';
import '../../domain/entities/itinerary_item.dart';
import '../providers/itinerary_providers.dart';
import 'schedule_activity_screen.dart';

final _itineraryMapModeProvider =
    StateProvider.autoDispose.family<bool, String>((ref, tripId) => false);

class ItineraryScreen extends ConsumerWidget {
  const ItineraryScreen({required this.trip, required this.isOwner, super.key});

  final Trip trip;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itineraryListProvider(trip.id));
    final proposals = ref.watch(activityListProvider(trip.id));
    final showMap = ref.watch(_itineraryMapModeProvider(trip.id));
    return RefreshIndicator(
      onRefresh: () => ref.refresh(itineraryListProvider(trip.id).future),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Daily itinerary',
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 4),
                            const Text(
                                'Your shared plan, organized by trip day.'),
                          ],
                        ),
                      ),
                      if (isOwner)
                        FilledButton.tonalIcon(
                          onPressed: () => _openScheduler(
                            context,
                            proposals.valueOrNull ?? const [],
                            items.valueOrNull ?? const [],
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.view_list_outlined),
                        label: Text('List'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.map_outlined),
                        label: Text('Map'),
                      ),
                    ],
                    selected: {showMap},
                    onSelectionChanged: (selection) => ref
                        .read(_itineraryMapModeProvider(trip.id).notifier)
                        .state = selection.first,
                  ),
                  const SizedBox(height: 22),
                  items.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) =>
                        Text('Unable to load itinerary: $error'),
                    data: (values) => values.isEmpty
                        ? _ItineraryEmpty(
                            isOwner: isOwner,
                            onAdd: () => _openScheduler(
                              context,
                              proposals.valueOrNull ?? const [],
                              const [],
                            ),
                          )
                        : showMap
                            ? _ItineraryMap(items: values)
                            : _ItineraryDays(
                                items: values,
                                isOwner: isOwner,
                                onMove: (index, direction) =>
                                    _move(ref, values, index, direction),
                                onStatus: (item, status) =>
                                    _changeStatus(context, ref, item, status),
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openScheduler(
    BuildContext context,
    List<ActivityProposal> proposals,
    List<ItineraryItem> itineraryItems,
  ) {
    final approved = proposals
        .where((item) => item.status == ProposalStatus.approved)
        .toList();
    if (approved.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Approve an activity suggestion before scheduling it.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScheduleActivityScreen(
          trip: trip,
          approvedProposals: approved,
          itineraryItems: itineraryItems,
        ),
      ),
    );
  }

  Future<void> _move(
    WidgetRef ref,
    List<ItineraryItem> items,
    int index,
    int direction,
  ) async {
    final target = index + direction;
    if (target < 0 || target >= items.length) return;
    final reordered = [...items];
    final item = reordered.removeAt(index);
    reordered.insert(target, item);
    await ref
        .read(itineraryControllerProvider.notifier)
        .reorder(trip.id, reordered.map((item) => item.id).toList());
  }

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    ItineraryItem item,
    ItineraryItemStatus status,
  ) async {
    final success = await ref
        .read(itineraryControllerProvider.notifier)
        .changeStatus(item, status);
    if (!context.mounted || success) return;
    final error = ref.read(itineraryControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error?.toString() ?? 'Unable to update item.')),
    );
  }
}

class _ItineraryMap extends StatelessWidget {
  const _ItineraryMap({required this.items});

  final List<ItineraryItem> items;

  @override
  Widget build(BuildContext context) {
    final mappedItems =
        items.where((item) => item.hasCoordinates).toList(growable: false);
    if (mappedItems.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'These itinerary activities do not have map points yet. '
            'New suggestions can choose a point from the activity form.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final center = LatLng(
      mappedItems.first.latitude!,
      mappedItems.first.longitude!,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 520,
            child: FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 13),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.tripweave',
                ),
                MarkerLayer(
                  markers: mappedItems
                      .map(
                        (item) => Marker(
                          point: LatLng(item.latitude!, item.longitude!),
                          width: 48,
                          height: 48,
                          child: IconButton.filled(
                            tooltip: item.title,
                            onPressed: () => _showActivity(context, item),
                            icon: const Icon(Icons.location_on),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (mappedItems.length < items.length) ...[
          const SizedBox(height: 10),
          Text(
            '${items.length - mappedItems.length} older '
            '${items.length - mappedItems.length == 1 ? 'activity has' : 'activities have'} '
            'no map point.',
          ),
        ],
      ],
    );
  }

  void _showActivity(BuildContext context, ItineraryItem item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(item.location),
            const SizedBox(height: 6),
            Text(
              '${TimeOfDay.fromDateTime(item.startAt).format(context)} – '
              '${TimeOfDay.fromDateTime(item.endAt).format(context)}',
            ),
            const SizedBox(height: 6),
            Text(item.status.label),
          ],
        ),
      ),
    );
  }
}

class _ItineraryDays extends StatelessWidget {
  const _ItineraryDays({
    required this.items,
    required this.isOwner,
    required this.onMove,
    required this.onStatus,
  });

  final List<ItineraryItem> items;
  final bool isOwner;
  final void Function(int index, int direction) onMove;
  final void Function(ItineraryItem item, ItineraryItemStatus status) onStatus;

  @override
  Widget build(BuildContext context) {
    final days = <DateTime, List<(int, ItineraryItem)>>{};
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final day = DateUtils.dateOnly(item.startAt);
      days.putIfAbsent(day, () => []).add((index, item));
    }
    final dayEntries = days.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: dayEntries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_dayLabel(entry.key),
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              ...entry.value.map((record) {
                final index = record.$1;
                final item = record.$2;
                final overlaps = items.any(
                  (other) => other.id != item.id && item.overlaps(other),
                );
                final localIndex = entry.value.indexOf(record);
                final previousIsSameDay = index > 0 &&
                    DateUtils.isSameDay(items[index - 1].startAt, item.startAt);
                final nextIsSameDay = index < items.length - 1 &&
                    DateUtils.isSameDay(items[index + 1].startAt, item.startAt);
                return _ItineraryCard(
                  item: item,
                  overlaps: overlaps,
                  showReorder: isOwner,
                  canMoveUp: localIndex > 0 && previousIsSameDay,
                  canMoveDown:
                      localIndex < entry.value.length - 1 && nextIsSameDay,
                  onMoveUp: () => onMove(index, -1),
                  onMoveDown: () => onMove(index, 1),
                  onStatus: (status) => onStatus(item, status),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  static String _dayLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _ItineraryCard extends StatelessWidget {
  const _ItineraryCard({
    required this.item,
    required this.overlaps,
    required this.showReorder,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onStatus,
  });

  final ItineraryItem item;
  final bool overlaps;
  final bool showReorder;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<ItineraryItemStatus> onStatus;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 58,
              child: Text(
                TimeOfDay.fromDateTime(item.startAt).format(context),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 4),
                  Text(item.location),
                  const SizedBox(height: 6),
                  Text(
                    '${TimeOfDay.fromDateTime(item.startAt).format(context)} – '
                    '${TimeOfDay.fromDateTime(item.endAt).format(context)}',
                  ),
                  if (overlaps) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Overlaps another activity',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(item.status.label),
                ],
              ),
            ),
            if (item.status == ItineraryItemStatus.scheduled)
              PopupMenuButton<ItineraryItemStatus>(
                onSelected: onStatus,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: ItineraryItemStatus.completed,
                    child: Text('Mark completed'),
                  ),
                  PopupMenuItem(
                    value: ItineraryItemStatus.cancelled,
                    child: Text('Cancel activity'),
                  ),
                ],
              ),
            if (showReorder)
              Column(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: canMoveUp ? onMoveUp : null,
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: canMoveDown ? onMoveDown : null,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ItineraryEmpty extends StatelessWidget {
  const _ItineraryEmpty({required this.isOwner, required this.onAdd});

  final bool isOwner;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.calendar_month_outlined, size: 48),
            const SizedBox(height: 12),
            const Text('No activities scheduled yet.'),
            if (isOwner) ...[
              const SizedBox(height: 14),
              FilledButton(
                  onPressed: onAdd, child: const Text('Add approved idea')),
            ],
          ],
        ),
      ),
    );
  }
}
