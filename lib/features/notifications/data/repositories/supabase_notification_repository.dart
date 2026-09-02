import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

class SupabaseNotificationRepository implements NotificationRepository {
  const SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AppNotification>> getNotifications() async {
    final rows = await _client
        .from('notifications')
        .select('*, actor:profiles!notifications_actor_id_fkey(display_name)')
        .order('created_at', ascending: false)
        .limit(100);

    return rows.map((row) {
      final actor = row['actor'] as Map<String, dynamic>?;
      return AppNotification(
        id: row['id'] as String,
        tripId: row['trip_id'] as String,
        proposalId: row['proposal_id'] as String?,
        title: row['title'] as String,
        message: row['message'] as String,
        actorName: actor?['display_name'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        readAt: row['read_at'] == null
            ? null
            : DateTime.parse(row['read_at'] as String).toLocal(),
      );
    }).toList(growable: false);
  }

  @override
  Future<void> markAsRead(String notificationId) => _client
      .from('notifications')
      .update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq(
        'id',
        notificationId,
      );

  @override
  Future<void> markAllAsRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('You are not signed in.');
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('recipient_id', userId)
        .isFilter('read_at', null);
  }
}
