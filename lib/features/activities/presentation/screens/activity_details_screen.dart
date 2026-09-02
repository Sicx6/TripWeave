import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../trips/domain/entities/trip.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/activity_proposal.dart';
import '../providers/activity_providers.dart';

class ActivityDetailsScreen extends ConsumerWidget {
  const ActivityDetailsScreen({
    required this.trip,
    required this.initialProposal,
    required this.isOwner,
    super.key,
  });

  final Trip trip;
  final ActivityProposal initialProposal;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proposals = ref.watch(activityListProvider(trip.id));
    final latest = proposals.valueOrNull;
    final matches = latest?.where((item) => item.id == initialProposal.id);
    final proposal =
        matches == null || matches.isEmpty ? initialProposal : matches.first;
    final operation = ref.watch(activityControllerProvider);
    final votingOpen = proposal.status == ProposalStatus.proposed ||
        proposal.status == ProposalStatus.voting;

    return Scaffold(
      appBar: AppBar(title: const Text('Activity details')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (proposal.imageUrl != null)
                      AspectRatio(
                        aspectRatio: 16 / 8,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.network(
                            proposal.imageUrl!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    if (proposal.imageUrl != null) const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            proposal.title,
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                        ),
                        Chip(label: Text(proposal.status.label)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _InfoChip(
                          icon: Icons.category_outlined,
                          label: proposal.displayCategory,
                        ),
                        _InfoChip(
                          icon: Icons.place_outlined,
                          label: proposal.location,
                        ),
                        _InfoChip(
                          icon: Icons.schedule_outlined,
                          label: _dateTime(context, proposal.proposedAt),
                        ),
                        _InfoChip(
                          icon: Icons.payments_outlined,
                          label: proposal.formattedCost,
                        ),
                      ],
                    ),
                    if (proposal.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 26),
                      Text('About this idea',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(proposal.description),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: proposal.submittedByAvatarUrl == null
                              ? null
                              : NetworkImage(proposal.submittedByAvatarUrl!),
                          child: proposal.submittedByAvatarUrl == null
                              ? const Icon(Icons.person_outline_rounded,
                                  size: 20)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Text('Suggested by ${proposal.submittedByName}'),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _VotePanel(
                      proposal: proposal,
                      enabled: votingOpen && !operation.isLoading,
                      onVote: (support) => _vote(
                        context,
                        ref,
                        proposal,
                        support,
                      ),
                    ),
                    if (isOwner && votingOpen) ...[
                      const SizedBox(height: 22),
                      Text('Owner decision',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      const Text(
                        'Voting helps the decision, but only the trip owner can approve or reject the proposal.',
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: operation.isLoading
                                  ? null
                                  : () => _decide(
                                        context,
                                        ref,
                                        proposal,
                                        ProposalStatus.rejected,
                                      ),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: operation.isLoading
                                  ? null
                                  : () => _decide(
                                        context,
                                        ref,
                                        proposal,
                                        ProposalStatus.approved,
                                      ),
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 28),
                    _ActivityCommentsSection(proposalId: proposal.id),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _dateTime(BuildContext context, DateTime value) {
    final date =
        '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    return '$date, ${TimeOfDay.fromDateTime(value).format(context)}';
  }

  static Future<void> _vote(
    BuildContext context,
    WidgetRef ref,
    ActivityProposal proposal,
    bool support,
  ) async {
    final success = await ref.read(activityControllerProvider.notifier).vote(
          tripId: proposal.tripId,
          proposalId: proposal.id,
          support: support,
        );
    if (!context.mounted || success) return;
    _showError(context, ref.read(activityControllerProvider).error);
  }

  static Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    ActivityProposal proposal,
    ProposalStatus status,
  ) async {
    final success = await ref
        .read(activityControllerProvider.notifier)
        .decide(proposal: proposal, status: status);
    if (!context.mounted || success) return;
    _showError(context, ref.read(activityControllerProvider).error);
  }

  static void _showError(BuildContext context, Object? error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(error?.toString() ?? 'Unable to update activity.')),
    );
  }
}

class _VotePanel extends StatelessWidget {
  const _VotePanel({
    required this.proposal,
    required this.enabled,
    required this.onVote,
  });

  final ActivityProposal proposal;
  final bool enabled;
  final ValueChanged<bool> onVote;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E8E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Group vote', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('${proposal.totalVotes} group member votes'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: enabled ? () => onVote(false) : null,
                  icon: const Icon(Icons.thumb_down_outlined),
                  label: Text('No (${proposal.noVotes})'),
                  style: proposal.currentUserVote == false
                      ? OutlinedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.errorContainer,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: enabled ? () => onVote(true) : null,
                  icon: const Icon(Icons.thumb_up_outlined),
                  label: Text('Yes (${proposal.yesVotes})'),
                  style: proposal.currentUserVote == true
                      ? FilledButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}

class _ActivityCommentsSection extends ConsumerStatefulWidget {
  const _ActivityCommentsSection({required this.proposalId});

  final String proposalId;

  @override
  ConsumerState<_ActivityCommentsSection> createState() =>
      _ActivityCommentsSectionState();
}

class _ActivityCommentsSectionState
    extends ConsumerState<_ActivityCommentsSection> {
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(activityCommentListProvider(widget.proposalId));
    final operation = ref.watch(activityControllerProvider);
    final currentUserId = ref.watch(currentUserProvider)?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comments', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _comment,
                minLines: 1,
                maxLines: 4,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Add to the discussion…',
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Post comment',
              onPressed: operation.isLoading ? null : _submit,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
        const SizedBox(height: 14),
        comments.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text('Unable to load comments: $error'),
          data: (items) => items.isEmpty
              ? const Text('No comments yet. Start the discussion.')
              : Column(
                  children: items
                      .map(
                        (comment) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundImage: comment.authorAvatarUrl == null
                                ? null
                                : NetworkImage(comment.authorAvatarUrl!),
                            child: comment.authorAvatarUrl == null
                                ? const Icon(Icons.person_outline_rounded)
                                : null,
                          ),
                          title: Text(comment.authorName),
                          subtitle: Text(comment.body),
                          trailing: comment.userId == currentUserId
                              ? IconButton(
                                  tooltip: 'Delete comment',
                                  onPressed: operation.isLoading
                                      ? null
                                      : () => ref
                                          .read(activityControllerProvider
                                              .notifier)
                                          .deleteComment(
                                            proposalId: widget.proposalId,
                                            commentId: comment.id,
                                          ),
                                  icon:
                                      const Icon(Icons.delete_outline_rounded),
                                )
                              : null,
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final body = _comment.text.trim();
    if (body.isEmpty) return;
    final success = await ref
        .read(activityControllerProvider.notifier)
        .addComment(proposalId: widget.proposalId, body: body);
    if (!mounted) return;
    if (success) {
      _comment.clear();
      return;
    }
    final error = ref.read(activityControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error?.toString() ?? 'Unable to post comment.')),
    );
  }
}
