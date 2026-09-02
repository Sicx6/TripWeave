import 'package:flutter/material.dart';

import '../../domain/entities/activity_proposal.dart';

class ActivityProposalCard extends StatelessWidget {
  const ActivityProposalCard({
    required this.proposal,
    required this.onTap,
    super.key,
  });

  final ActivityProposal proposal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  image: proposal.imageUrl == null
                      ? null
                      : DecorationImage(
                          image: NetworkImage(proposal.imageUrl!),
                          fit: BoxFit.cover,
                        ),
                ),
                child: proposal.imageUrl == null
                    ? Icon(_categoryIcon(proposal.category))
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proposal.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${proposal.displayCategory} • ${proposal.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.thumb_up_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                        Text('${proposal.yesVotes}'),
                        const SizedBox(width: 12),
                        Text(proposal.formattedCost),
                        const Spacer(),
                        Text(
                          proposal.status.label,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _categoryIcon(String category) => switch (category) {
        'Attractions' => Icons.local_activity_outlined,
        'Restaurants' => Icons.restaurant_outlined,
        'Accommodation' => Icons.hotel_outlined,
        'Transport' => Icons.directions_bus_outlined,
        'Shopping' => Icons.shopping_bag_outlined,
        _ => Icons.category_outlined,
      };
}
