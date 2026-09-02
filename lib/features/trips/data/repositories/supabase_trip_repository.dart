import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/trip.dart';
import '../../domain/repositories/trip_repository.dart';

class SupabaseTripRepository implements TripRepository {
  SupabaseTripRepository(this._client);

  final SupabaseClient _client;
  static const _uuid = Uuid();

  @override
  Future<List<Trip>> getTrips() async {
    final rows = await _client
        .from('trips')
        .select()
        .isFilter('deleted_at', null)
        .order('start_date');
    return rows.map(_mapTrip).toList(growable: false);
  }

  @override
  Future<Trip> createTrip(TripDraft draft) async {
    final userId = _requireUserId();
    final tripId = _uuid.v4();
    final row = await _client
        .from('trips')
        .insert({
          'id': tripId,
          'owner_id': userId,
          'destination': draft.destination.trim(),
          'description': draft.description.trim(),
          'start_date': _dateOnly(draft.startDate),
          'end_date': _dateOnly(draft.endDate),
          'budget': _moneyValue(draft.budgetCents),
          'status': TripStatus.planning.name,
        })
        .select()
        .single();
    final createdTrip = _mapTrip(row);
    final coverUrl = await _uploadCover(
      tripId: tripId,
      imagePath: draft.coverImagePath,
    );
    if (coverUrl == null) return createdTrip;

    final tripWithCover = await _client
        .from('trips')
        .update({'cover_image_url': coverUrl})
        .eq('id', tripId)
        .eq('version', createdTrip.version)
        .select()
        .single();
    return _mapTrip(tripWithCover);
  }

  @override
  Future<Trip> updateTrip({
    required Trip trip,
    required TripDraft draft,
  }) async {
    final coverUrl = draft.coverImagePath == null
        ? trip.coverImageUrl
        : await _uploadCover(
            tripId: trip.id,
            imagePath: draft.coverImagePath,
          );

    final row = await _client
        .from('trips')
        .update({
          'destination': draft.destination.trim(),
          'description': draft.description.trim(),
          'start_date': _dateOnly(draft.startDate),
          'end_date': _dateOnly(draft.endDate),
          'budget': _moneyValue(draft.budgetCents),
          'cover_image_url': coverUrl,
        })
        .eq('id', trip.id)
        .eq('version', trip.version)
        .select()
        .maybeSingle();

    if (row == null) throw const TripConflictException();
    return _mapTrip(row);
  }

  @override
  Future<void> changeStatus({
    required String tripId,
    required int expectedVersion,
    required TripStatus status,
  }) async {
    final row = await _client
        .from('trips')
        .update({'status': status.name})
        .eq('id', tripId)
        .eq('version', expectedVersion)
        .select('id')
        .maybeSingle();
    if (row == null) throw const TripConflictException();
  }

  String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('You are not signed in.');
    return userId;
  }

  Future<String?> _uploadCover({
    required String tripId,
    required String? imagePath,
  }) async {
    if (imagePath == null) return null;
    final extension = imagePath.split('.').last.toLowerCase();
    final storagePath = '$tripId/cover.$extension';
    await _client.storage.from('trip-covers').upload(
          storagePath,
          File(imagePath),
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('trip-covers').getPublicUrl(storagePath);
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _moneyValue(int cents) => (cents / 100).toStringAsFixed(2);

  static Trip _mapTrip(Map<String, dynamic> row) {
    final rawBudget = row['budget'];
    final budget =
        rawBudget is num ? rawBudget.toString() : rawBudget as String? ?? '0';
    return Trip(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      destination: row['destination'] as String,
      description: row['description'] as String? ?? '',
      startDate: DateTime.parse(row['start_date'] as String),
      endDate: DateTime.parse(row['end_date'] as String),
      budgetCents: (num.parse(budget) * 100).round(),
      status: TripStatus.fromDatabase(row['status'] as String),
      coverImageUrl: row['cover_image_url'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      version: row['version'] as int,
    );
  }
}

class TripConflictException implements Exception {
  const TripConflictException();

  @override
  String toString() =>
      'This trip changed on another device. Refresh it and try again.';
}
