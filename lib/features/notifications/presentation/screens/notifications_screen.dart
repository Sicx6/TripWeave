import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../activities/presentation/providers/activity_providers.dart';
import '../../../activities/presentation/screens/activity_details_screen.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../trips/domain/entities/trip.dart';
import '../../../trips/presentation/providers/trip_providers.dart';
import '../../../trips/presentation/screens/trip_overview_screen.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notification_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationListProvider);
    final trips = ref.watch(tripListProvider).valueOrNull ?? const <Trip>[];
    final operation = ref.watch(notificationControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: operation.isLoading ||
                    notifications.valueOrNull?.every((item) => item.isRead) ==
                        true
                ? null
                : () => ref
                    .read(notificationControllerProvider.notifier)
                    .markAllAsRead(),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(notificationListProvider.future),
        child: notifications.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 120),
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: 12),
              Text('Unable to load notifications.\n$error',
                  textAlign: TextAlign.center),
            ],
          ),
          data: (items) => items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Icon(Icons.notifications_none_rounded, size: 52),
                    SizedBox(height: 12),
                    Text('No notifications yet', textAlign: TextAlign.center),
                    SizedBox(height: 6),
                    Text(
                      'New trip activity suggestions will appear here.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _NotificationTile(
                      notification: item,
                      onTap: () => _openNotification(
                        context,
                        ref,
                        item,
                        trips,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _openNotification(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
    List<Trip> trips,
  ) async {
    if (!notification.isRead) {
      await ref
          .read(notificationControllerProvider.notifier)
          .markAsRead(notification.id);
    }
    if (!context.mounted) return;

    final matchingTrips = trips.where((trip) => trip.id == notification.tripId);
    if (matchingTrips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This trip is no longer available.')),
      );
      return;
    }
    final trip = matchingTrips.first;
    if (notification.proposalId != null) {
      try {
        final proposals = await ref.read(activityListProvider(trip.id).future);
        final matches = proposals.where(
          (proposal) => proposal.id == notification.proposalId,
        );
        if (matches.isNotEmpty && context.mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ActivityDetailsScreen(
                trip: trip,
                initialProposal: matches.first,
                isOwner: trip.ownerId == ref.read(currentUserProvider)?.id,
              ),
            ),
          );
          return;
        }
      } catch (_) {
        // The trip overview remains a useful fallback if the suggestion moved.
      }
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripOverviewScreen(trip: trip),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: notification.isRead
          ? null
          : Theme.of(context).colorScheme.primaryContainer.withOpacity(.45),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: Icon(notification.isRead
              ? Icons.lightbulb_outline_rounded
              : Icons.lightbulb_rounded),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight:
                notification.isRead ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${notification.message}\n${_timeLabel(notification.createdAt)}',
        ),
        isThreeLine: true,
        trailing: notification.isRead
            ? null
            : const Icon(Icons.circle, size: 10),
      ),
    );
  }

  static String _timeLabel(DateTime value) {
    final difference = DateTime.now().difference(value);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes} min ago';
    if (difference.inDays < 1) return '${difference.inHours} hr ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${value.day}/${value.month}/${value.year}';
  }
}
