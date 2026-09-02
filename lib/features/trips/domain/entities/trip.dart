enum TripStatus {
  draft,
  planning,
  finalized,
  active,
  completed,
  archived,
  cancelled;

  String get label => switch (this) {
        TripStatus.draft => 'Draft',
        TripStatus.planning => 'Planning',
        TripStatus.finalized => 'Finalized',
        TripStatus.active => 'Active',
        TripStatus.completed => 'Completed',
        TripStatus.archived => 'Archived',
        TripStatus.cancelled => 'Cancelled',
      };

  static TripStatus fromDatabase(String value) {
    return TripStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TripStatus.draft,
    );
  }
}

class Trip {
  const Trip({
    required this.id,
    required this.ownerId,
    required this.destination,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.budgetCents,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.coverImageUrl,
  });

  final String id;
  final String ownerId;
  final String destination;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final int budgetCents;
  final TripStatus status;
  final String? coverImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  bool get isUpcoming =>
      status != TripStatus.archived &&
      status != TripStatus.cancelled &&
      status != TripStatus.completed &&
      endDate.isAfter(DateTime.now());

  bool get isActive => status == TripStatus.active;

  String get formattedBudget {
    final whole = budgetCents ~/ 100;
    final cents = (budgetCents % 100).toString().padLeft(2, '0');
    return 'RM $whole.$cents';
  }
}
