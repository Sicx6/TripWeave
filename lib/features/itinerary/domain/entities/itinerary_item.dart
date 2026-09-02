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

  bool overlaps(ItineraryItem other) {
    if (status == ItineraryItemStatus.cancelled ||
        other.status == ItineraryItemStatus.cancelled) {
      return false;
    }
    return startAt.isBefore(other.endAt) && endAt.isAfter(other.startAt);
  }
}
