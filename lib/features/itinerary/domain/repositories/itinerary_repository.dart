import '../entities/itinerary_item.dart';

abstract interface class ItineraryRepository {
  Future<List<ItineraryItem>> getItems(String tripId);

  Future<void> addApprovedProposal({
    required String tripId,
    required String proposalId,
    required DateTime startAt,
    required DateTime endAt,
  });

  Future<void> reorder({
    required String tripId,
    required List<String> orderedItemIds,
  });

  Future<void> changeStatus({
    required ItineraryItem item,
    required ItineraryItemStatus status,
  });
}
