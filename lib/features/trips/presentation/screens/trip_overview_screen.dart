import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../activities/presentation/screens/activity_suggestions_screen.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../expenses/presentation/screens/expenses_screen.dart';
import '../../../itinerary/presentation/screens/itinerary_screen.dart';
import '../../../members/presentation/screens/members_screen.dart';
import '../../domain/entities/trip.dart';

class TripOverviewScreen extends ConsumerStatefulWidget {
  const TripOverviewScreen({required this.trip, super.key});

  final Trip trip;

  @override
  ConsumerState<TripOverviewScreen> createState() => _TripOverviewScreenState();
}

class _TripOverviewScreenState extends ConsumerState<TripOverviewScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserProvider)?.id;
    final isOwner = widget.trip.ownerId == userId;
    final pages = [
      _OverviewTab(trip: widget.trip),
      ActivitySuggestionsScreen(
        trip: widget.trip,
        isOwner: isOwner,
      ),
      ItineraryScreen(
        trip: widget.trip,
        isOwner: isOwner,
      ),
      ExpensesScreen(
        trip: widget.trip,
        currentUserId: userId ?? '',
        isOwner: isOwner,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trip.destination),
        actions: [
          IconButton(
            tooltip: 'Members',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MembersScreen(
                  trip: widget.trip,
                  isOwner: isOwner,
                ),
              ),
            ),
            icon: const Icon(Icons.group_outlined),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outline_rounded),
            selectedIcon: Icon(Icons.lightbulb_rounded),
            label: 'Suggestions',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Itinerary',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Expenses',
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 8,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: trip.coverImageUrl == null
                        ? Container(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            child:
                                const Icon(Icons.landscape_outlined, size: 64),
                          )
                        : Image.network(trip.coverImageUrl!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 24),
                Text(trip.destination,
                    style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _OverviewDetail(
                      icon: Icons.calendar_today_outlined,
                      label:
                          '${_date(trip.startDate)} – ${_date(trip.endDate)}',
                    ),
                    _OverviewDetail(
                      icon: Icons.account_balance_wallet_outlined,
                      label: trip.formattedBudget,
                    ),
                    _OverviewDetail(
                      icon: Icons.flag_outlined,
                      label: trip.status.label,
                    ),
                  ],
                ),
                if (trip.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('About this trip',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(trip.description),
                ],
                const SizedBox(height: 28),
                Text('Plan together',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text(
                  'Open Suggestions to add ideas, vote as a group, and let the owner approve the best activities.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class _OverviewDetail extends StatelessWidget {
  const _OverviewDetail({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}
