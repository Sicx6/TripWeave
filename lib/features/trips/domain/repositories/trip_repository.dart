import '../entities/trip.dart';

class TripDraft {
  const TripDraft({
    required this.destination,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.budgetCents,
    this.coverImagePath,
  });

  final String destination;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final int budgetCents;
  final String? coverImagePath;
}

abstract interface class TripRepository {
  Future<List<Trip>> getTrips();
  Future<Trip> createTrip(TripDraft draft);
  Future<Trip> updateTrip({required Trip trip, required TripDraft draft});
  Future<void> changeStatus({
    required String tripId,
    required int expectedVersion,
    required TripStatus status,
  });
}
