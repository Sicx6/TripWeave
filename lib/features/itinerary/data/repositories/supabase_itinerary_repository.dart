import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/itinerary_item.dart';
import '../../domain/repositories/itinerary_repository.dart';

class SupabaseItineraryRepository implements ItineraryRepository {
  SupabaseItineraryRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ItineraryItem>> getItems(String tripId) async {
    final rows = await _client
        .from('itinerary_items')
        .select()
        .eq('trip_id', tripId)
        .isFilter('deleted_at', null)
        .order('position')
        .order('start_at');
    return rows.map(_mapItem).toList(growable: false);
  }

  @override
  Future<void> addApprovedProposal({
    required String tripId,
    required String proposalId,
    required DateTime startAt,
    required DateTime endAt,
  }) =>
      _client.rpc(
        'add_proposal_to_itinerary',
        params: {
          'target_trip_id': tripId,
          'target_proposal_id': proposalId,
          'item_start_at': startAt.toUtc().toIso8601String(),
          'item_end_at': endAt.toUtc().toIso8601String(),
        },
      );

  @override
  Future<void> reorder({
    required String tripId,
    required List<String> orderedItemIds,
  }) =>
      _client.rpc(
        'reorder_itinerary_items',
        params: {
          'target_trip_id': tripId,
          'ordered_item_ids': orderedItemIds,
        },
      );

  @override
  Future<void> changeStatus({
    required ItineraryItem item,
    required ItineraryItemStatus status,
  }) =>
      _client.rpc(
        'change_itinerary_item_status',
        params: {
          'target_item_id': item.id,
          'expected_version': item.version,
          'new_status': status.name,
        },
      );

  static ItineraryItem _mapItem(Map<String, dynamic> row) => ItineraryItem(
        id: row['id'] as String,
        tripId: row['trip_id'] as String,
        proposalId: row['proposal_id'] as String?,
        title: row['title'] as String,
        location: row['location'] as String,
        startAt: DateTime.parse(row['start_at'] as String).toLocal(),
        endAt: DateTime.parse(row['end_at'] as String).toLocal(),
        position: row['position'] as int,
        status: ItineraryItemStatus.fromDatabase(row['status'] as String),
        version: row['version'] as int,
      );
}
