import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../trips/domain/entities/trip.dart';
import '../../domain/entities/trip_invitation.dart';
import '../../domain/entities/trip_member.dart';
import '../providers/member_providers.dart';

class MembersScreen extends ConsumerWidget {
  const MembersScreen({
    required this.trip,
    required this.isOwner,
    super.key,
  });

  final Trip trip;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(memberListProvider(trip.id));
    final invitations = isOwner
        ? ref.watch(invitationListProvider(trip.id))
        : const AsyncData<List<TripInvitation>>([]);
    final operation = ref.watch(memberControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members and invitations'),
        actions: [
          if (!isOwner)
            IconButton(
              tooltip: 'Leave trip',
              onPressed: operation.isLoading
                  ? null
                  : () => _confirmLeave(context, ref),
              icon: const Icon(Icons.exit_to_app_rounded),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(memberListProvider(trip.id));
          if (isOwner) ref.invalidate(invitationListProvider(trip.id));
          await ref.read(memberListProvider(trip.id).future);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Travel group',
                                  style:
                                      Theme.of(context).textTheme.displaySmall),
                              const SizedBox(height: 6),
                              Text(trip.destination),
                            ],
                          ),
                        ),
                        if (isOwner)
                          FilledButton.tonalIcon(
                            onPressed: operation.isLoading
                                ? null
                                : () => _createInvitation(context, ref),
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text('Invite'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Text('Members',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    members.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (error, _) =>
                          Text('Unable to load members: $error'),
                      data: (items) => Column(
                        children: items
                            .map(
                              (member) => _MemberTile(
                                member: member,
                                canRemove: isOwner &&
                                    member.role != TripMemberRole.owner,
                                canTransfer: isOwner &&
                                    member.role != TripMemberRole.owner,
                                onRemove: () =>
                                    _confirmRemove(context, ref, member),
                                onTransfer: () =>
                                    _confirmTransfer(context, ref, member),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    if (isOwner) ...[
                      const SizedBox(height: 28),
                      Text('Invitation codes',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 6),
                      const Text(
                        'Each code is valid for one person and expires after seven days.',
                      ),
                      const SizedBox(height: 12),
                      invitations.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, _) =>
                            Text('Unable to load invitations: $error'),
                        data: (items) => items.isEmpty
                            ? const _NoInvitations()
                            : Column(
                                children: items
                                    .map(
                                      (invitation) => _InvitationTile(
                                        invitation: invitation,
                                        onCopy: () => _copy(
                                          context,
                                          invitation.inviteCode,
                                          'Invitation code copied.',
                                        ),
                                        onRevoke: invitation.isUsable
                                            ? () => _revoke(
                                                  context,
                                                  ref,
                                                  invitation,
                                                )
                                            : null,
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createInvitation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final invitation = await ref
        .read(memberControllerProvider.notifier)
        .createInvitation(trip.id);
    if (!context.mounted) return;
    if (invitation == null) {
      _showError(context, ref.read(memberControllerProvider).error);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invitation created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this one-time code with one trip member:'),
            const SizedBox(height: 14),
            SelectableText(
              invitation.inviteCode,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    letterSpacing: 3,
                  ),
            ),
            const SizedBox(height: 10),
            Text('Expires ${_date(invitation.expiresAt)}'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _copy(
              context,
              'Join my ${trip.destination} trip on TripWeave. '
                  'Invitation code: ${invitation.inviteCode}',
              'Invitation message copied.',
            ),
            icon: const Icon(Icons.message_outlined),
            label: const Text('Copy message'),
          ),
          FilledButton.icon(
            onPressed: () => _copy(
              context,
              invitation.inviteCode,
              'Invitation code copied.',
            ),
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy code'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    TripMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${member.displayName}?'),
        content: const Text(
          'They will immediately lose access to this trip and its activities.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep member'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await ref
        .read(memberControllerProvider.notifier)
        .removeMember(tripId: trip.id, userId: member.userId);
    if (!context.mounted || success) return;
    _showError(context, ref.read(memberControllerProvider).error);
  }

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this trip?'),
        content: const Text(
          'You will lose access to the itinerary, suggestions, and expenses.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave trip'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success =
        await ref.read(memberControllerProvider.notifier).leaveTrip(trip.id);
    if (!context.mounted) return;
    if (!success) {
      _showError(context, ref.read(memberControllerProvider).error);
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _confirmTransfer(
    BuildContext context,
    WidgetRef ref,
    TripMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Make ${member.displayName} the owner?'),
        content: const Text(
          'They will receive owner permissions. You will become a regular member.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Transfer ownership'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await ref
        .read(memberControllerProvider.notifier)
        .transferOwnership(tripId: trip.id, newOwnerId: member.userId);
    if (!context.mounted) return;
    if (!success) {
      _showError(context, ref.read(memberControllerProvider).error);
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    TripInvitation invitation,
  ) async {
    final success =
        await ref.read(memberControllerProvider.notifier).revokeInvitation(
              tripId: trip.id,
              invitationId: invitation.id,
            );
    if (!context.mounted || success) return;
    _showError(context, ref.read(memberControllerProvider).error);
  }

  static Future<void> _copy(
    BuildContext context,
    String value,
    String message,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static void _showError(BuildContext context, Object? error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error?.toString() ?? 'Unable to update members.')),
    );
  }

  static String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.canRemove,
    required this.canTransfer,
    required this.onRemove,
    required this.onTransfer,
  });

  final TripMember member;
  final bool canRemove;
  final bool canTransfer;
  final VoidCallback onRemove;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage:
              member.avatarUrl == null ? null : NetworkImage(member.avatarUrl!),
          child: member.avatarUrl == null
              ? Text(member.displayName.substring(0, 1).toUpperCase())
              : null,
        ),
        title: Text(member.displayName),
        subtitle: Text(member.role.label),
        trailing: canRemove || canTransfer
            ? PopupMenuButton<String>(
                onSelected: (value) =>
                    value == 'transfer' ? onTransfer() : onRemove(),
                itemBuilder: (_) => [
                  if (canTransfer)
                    const PopupMenuItem(
                      value: 'transfer',
                      child: Text('Transfer ownership'),
                    ),
                  if (canRemove)
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove member'),
                    ),
                ],
              )
            : null,
      ),
    );
  }
}

class _InvitationTile extends StatelessWidget {
  const _InvitationTile({
    required this.invitation,
    required this.onCopy,
    required this.onRevoke,
  });

  final TripInvitation invitation;
  final VoidCallback onCopy;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(
          invitation.inviteCode,
          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 2),
        ),
        subtitle: Text(invitation.status.label),
        onTap: invitation.isUsable ? onCopy : null,
        trailing: onRevoke == null
            ? null
            : IconButton(
                tooltip: 'Revoke invitation',
                onPressed: onRevoke,
                icon: const Icon(Icons.link_off_rounded),
              ),
      ),
    );
  }
}

class _NoInvitations extends StatelessWidget {
  const _NoInvitations();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Text('No invitation codes have been created.'),
      ),
    );
  }
}
