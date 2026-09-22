enum ItineraryItemStatus {
  scheduled,
  completed,
  cancelled;

  String get label => switch (this) {
        ItineraryItemStatus.scheduled => 'Scheduled',
        ItineraryItemStatus.completed => 'Completed',
        ItineraryItemStatus.cancelled => 'Cancelled',
      };

  static ItineraryItemStatus fromDatabase(String value) {
    return ItineraryItemStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ItineraryItemStatus.scheduled,
    );
  }
}

class ItineraryItem {
  const ItineraryItem({
    required this.id,
    required this.tripId,
    required this.title,
    required this.location,
    required this.startAt,
    required this.endAt,
    required this.position,
    required this.status,
    required this.version,
    this.proposalId,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String tripId;
  final String? proposalId;
  final String title;
  final String location;
  final DateTime startAt;
  final DateTime endAt;
  final int position;
  final ItineraryItemStatus status;
  final int version;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  bool overlaps(ItineraryItem other) {
    if (status == ItineraryItemStatus.cancelled ||
        other.status == ItineraryItemStatus.cancelled) {
      return false;
    }
    return startAt.isBefore(other.endAt) && endAt.isAfter(other.startAt);
  }
}

List<ItineraryItem> findItineraryConflicts({
  required List<ItineraryItem> items,
  required DateTime startAt,
  required DateTime endAt,
}) {
  return items.where((item) {
    if (item.status == ItineraryItemStatus.cancelled) return false;
    return startAt.isBefore(item.endAt) && endAt.isAfter(item.startAt);
  }).toList(growable: false);
}
