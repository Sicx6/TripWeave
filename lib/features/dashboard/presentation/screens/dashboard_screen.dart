import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/profile_screen.dart';
import '../../../members/presentation/screens/join_trip_screen.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../trips/domain/entities/trip.dart';
import '../../../trips/presentation/providers/trip_providers.dart';
import '../../../trips/presentation/screens/create_edit_trip_screen.dart';
import '../../../trips/presentation/screens/trip_overview_screen.dart';
import '../../../trips/presentation/widgets/trip_card.dart';
import '../widgets/dashboard_empty_state.dart';

enum _DashboardFilter { upcoming, active, completed }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  _DashboardFilter _filter = _DashboardFilter.upcoming;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final trips = ref.watch(tripListProvider);
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_rounded),
            SizedBox(width: 8),
            Text('TripWeave', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Join a trip',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const JoinTripScreen()),
            ),
            icon: const Icon(Icons.group_add_outlined),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
            icon: Badge(
              isLabelVisible: unreadNotifications > 0,
              label: Text(unreadNotifications > 99
                  ? '99+'
                  : unreadNotifications.toString()),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Profile',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              icon: CircleAvatar(
                radius: 16,
                backgroundImage: user?.avatarUrl == null
                    ? null
                    : NetworkImage(user!.avatarUrl!),
                child: user?.avatarUrl == null
                    ? const Icon(Icons.person_rounded, size: 19)
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(tripListProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(user?.displayName),
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ready to weave your next trip together?',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 30),
                      Row(
                        children: [
                          Text('My Trips',
                              style: Theme.of(context).textTheme.headlineSmall),
                          const Spacer(),
                          FilledButton.tonalIcon(
                            onPressed: _openCreateTrip,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('New trip'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _DashboardFilter.values
                            .map(
                              (filter) => ChoiceChip(
                                label: Text(_filterLabel(filter)),
                                selected: _filter == filter,
                                onSelected: (_) =>
                                    setState(() => _filter = filter),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 20),
                      trips.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (error, _) => _TripLoadError(
                          message: error.toString(),
                          onRetry: () => ref.invalidate(tripListProvider),
                        ),
                        data: (allTrips) => _buildTripContent(
                          allTrips,
                          user?.id,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripContent(List<Trip> allTrips, String? userId) {
    if (allTrips.isEmpty) {
      return DashboardEmptyState(onCreateTrip: _openCreateTrip);
    }
    final visibleTrips = allTrips.where(_matchesFilter).toList();
    if (visibleTrips.isEmpty) {
      return _FilteredEmptyState(filterLabel: _filterLabel(_filter));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 2 : 1;
        const gap = 16.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: visibleTrips
              .map(
                (trip) => SizedBox(
                  width: width,
                  child: TripCard(
                    trip: trip,
                    canManage: trip.ownerId == userId,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TripOverviewScreen(trip: trip),
                      ),
                    ),
                    onAction: (action) => _handleAction(trip, action),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  bool _matchesFilter(Trip trip) {
    return switch (_filter) {
      _DashboardFilter.upcoming => trip.isUpcoming && !trip.isActive,
      _DashboardFilter.active => trip.isActive,
      _DashboardFilter.completed => trip.status == TripStatus.completed ||
          trip.status == TripStatus.archived ||
          trip.status == TripStatus.cancelled ||
          (!trip.isUpcoming && !trip.isActive),
    };
  }

  Future<void> _openCreateTrip() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateEditTripScreen()),
    );
  }

  Future<void> _handleAction(Trip trip, TripCardAction action) async {
    if (action == TripCardAction.edit) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CreateEditTripScreen(trip: trip)),
      );
      return;
    }

    final targetStatus = switch (action) {
      TripCardAction.advance => _nextStatus(trip.status),
      TripCardAction.cancel => TripStatus.cancelled,
      TripCardAction.archive => TripStatus.archived,
      TripCardAction.edit => null,
    };
    if (targetStatus == null) return;
    final verb = switch (action) {
      TripCardAction.advance => 'mark as ${targetStatus.label.toLowerCase()}',
      TripCardAction.cancel => 'cancel',
      TripCardAction.archive => 'archive',
      TripCardAction.edit => 'edit',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${verb[0].toUpperCase()}${verb.substring(1)} trip?'),
        content: Text(
          action == TripCardAction.cancel
              ? 'The trip remains in your records but is marked as cancelled.'
              : action == TripCardAction.archive
                  ? 'The trip moves out of your active planning list.'
                  : 'This moves the trip to the next stage of its lifecycle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep trip'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(verb[0].toUpperCase() + verb.substring(1)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final success = await ref
        .read(tripControllerProvider.notifier)
        .changeStatus(trip, targetStatus);
    if (!mounted || success) return;
    final error = ref.read(tripControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error?.toString() ?? 'Unable to update trip.')),
    );
  }

  static String _greeting(String? displayName) {
    final name = displayName?.trim();
    return name == null || name.isEmpty ? 'Welcome back' : 'Hello, $name';
  }

  static String _filterLabel(_DashboardFilter filter) => switch (filter) {
        _DashboardFilter.upcoming => 'Upcoming',
        _DashboardFilter.active => 'Active',
        _DashboardFilter.completed => 'Completed',
      };

  static TripStatus? _nextStatus(TripStatus status) => switch (status) {
        TripStatus.draft => TripStatus.planning,
        TripStatus.planning => TripStatus.finalized,
        TripStatus.finalized => TripStatus.active,
        TripStatus.active => TripStatus.completed,
        _ => null,
      };
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState({required this.filterLabel});

  final String filterLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'No ${filterLabel.toLowerCase()} trips yet.',
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _TripLoadError extends StatelessWidget {
  const _TripLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 34),
          const SizedBox(height: 10),
          const Text('We could not load your trips.'),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
