import 'package:flutter/material.dart';

import '../../domain/entities/trip.dart';

enum TripCardAction { edit, advance, cancel, archive }

class TripCard extends StatelessWidget {
  const TripCard({
    required this.trip,
    required this.canManage,
    required this.onTap,
    required this.onAction,
    super.key,
  });

  final Trip trip;
  final bool canManage;
  final VoidCallback onTap;
  final ValueChanged<TripCardAction> onAction;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 7,
              child: trip.coverImageUrl == null
                  ? _CoverPlaceholder(destination: trip.destination)
                  : Image.network(
                      trip.coverImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _CoverPlaceholder(destination: trip.destination),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          trip.destination,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      if (canManage)
                        PopupMenuButton<TripCardAction>(
                          tooltip: 'Trip actions',
                          onSelected: onAction,
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: TripCardAction.edit,
                              child: Text('Edit trip'),
                            ),
                            if (_nextStepLabel(trip.status) case final label?)
                              PopupMenuItem(
                                value: TripCardAction.advance,
                                child: Text(label),
                              ),
                            if (trip.status != TripStatus.cancelled &&
                                trip.status != TripStatus.archived)
                              const PopupMenuItem(
                                value: TripCardAction.cancel,
                                child: Text('Cancel trip'),
                              ),
                            if (trip.status != TripStatus.archived)
                              const PopupMenuItem(
                                value: TripCardAction.archive,
                                child: Text('Archive trip'),
                              ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _Detail(
                        icon: Icons.calendar_today_outlined,
                        label:
                            '${_date(trip.startDate)} – ${_date(trip.endDate)}',
                      ),
                      _Detail(
                        icon: Icons.account_balance_wallet_outlined,
                        label: trip.formattedBudget,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(trip.status.label),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static String? _nextStepLabel(TripStatus status) => switch (status) {
        TripStatus.draft => 'Start planning',
        TripStatus.planning => 'Finalize plan',
        TripStatus.finalized => 'Start trip',
        TripStatus.active => 'Mark completed',
        _ => null,
      };
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.destination});

  final String destination;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF176B68), Color(0xFF73B6A5)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: 18,
            top: 18,
            child: Icon(Icons.flight_takeoff_rounded,
                color: Colors.white24, size: 70),
          ),
          Positioned(
            left: 18,
            bottom: 16,
            child: Text(
              destination.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
