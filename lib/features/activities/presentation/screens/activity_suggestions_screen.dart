import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../trips/domain/entities/trip.dart';
import '../providers/activity_providers.dart';
import '../widgets/activity_proposal_card.dart';
import 'activity_details_screen.dart';
import 'add_activity_screen.dart';

class ActivitySuggestionsScreen extends ConsumerWidget {
  const ActivitySuggestionsScreen({
    required this.trip,
    required this.isOwner,
    super.key,
  });

  final Trip trip;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proposals = ref.watch(activityListProvider(trip.id));
    return RefreshIndicator(
      onRefresh: () => ref.refresh(activityListProvider(trip.id).future),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Activity suggestions',
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 4),
                            const Text('Share an idea and let the group vote.'),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddActivityScreen(trip: trip),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Suggest'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  proposals.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(36),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (error, _) => _SuggestionError(
                      message: error.toString(),
                      onRetry: () =>
                          ref.invalidate(activityListProvider(trip.id)),
                    ),
                    data: (items) => items.isEmpty
                        ? _SuggestionEmptyState(
                            onAdd: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AddActivityScreen(trip: trip),
                              ),
                            ),
                          )
                        : Column(
                            children: items
                                .map(
                                  (proposal) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: ActivityProposalCard(
                                      proposal: proposal,
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ActivityDetailsScreen(
                                            trip: trip,
                                            initialProposal: proposal,
                                            isOwner: isOwner,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionEmptyState extends StatelessWidget {
  const _SuggestionEmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(Icons.lightbulb_outline_rounded,
              size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text('No suggestions yet',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Be the first person to add an activity idea.'),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add activity'),
          ),
        ],
      ),
    );
  }
}

class _SuggestionError extends StatelessWidget {
  const _SuggestionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Text('Unable to load suggestions.'),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
