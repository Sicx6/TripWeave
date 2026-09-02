import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/trip_invitation.dart';
import '../providers/member_providers.dart';

class JoinTripScreen extends ConsumerStatefulWidget {
  const JoinTripScreen({super.key});

  @override
  ConsumerState<JoinTripScreen> createState() => _JoinTripScreenState();
}

class _JoinTripScreenState extends ConsumerState<JoinTripScreen> {
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(joinTripControllerProvider.notifier).clear();
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(joinTripControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Join a trip')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Enter your invitation',
                      style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 8),
                  const Text(
                    'Ask the trip owner for the 10-character invitation code.',
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[a-fA-F0-9]')),
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Invitation code',
                      hintText: 'A1B2C3D4E5',
                      prefixIcon: Icon(Icons.key_rounded),
                    ),
                    onChanged: (_) =>
                        ref.read(joinTripControllerProvider.notifier).clear(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: state.isLoading ? null : _preview,
                      child: state.isLoading
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Check invitation'),
                    ),
                  ),
                  if (state.hasError) ...[
                    const SizedBox(height: 16),
                    Text(
                      state.error.toString(),
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  if (state.valueOrNull case final preview?) ...[
                    const SizedBox(height: 24),
                    _InvitationPreviewCard(
                      preview: preview,
                      busy: state.isLoading,
                      onDecline: _decline,
                      onAccept: _accept,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _preview() async {
    if (_code.text.trim().length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the complete 10-character code.')),
      );
      return;
    }
    await ref.read(joinTripControllerProvider.notifier).preview(_code.text);
  }

  Future<void> _accept() async {
    final success =
        await ref.read(joinTripControllerProvider.notifier).accept(_code.text);
    if (!mounted || !success) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You joined the trip successfully.')),
    );
  }

  Future<void> _decline() async {
    final success =
        await ref.read(joinTripControllerProvider.notifier).decline(_code.text);
    if (!mounted || !success) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invitation declined.')),
    );
  }
}

class _InvitationPreviewCard extends StatelessWidget {
  const _InvitationPreviewCard({
    required this.preview,
    required this.busy,
    required this.onDecline,
    required this.onAccept,
  });

  final InvitationPreview preview;
  final bool busy;
  final VoidCallback onDecline;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are invited!',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            _PreviewRow(icon: Icons.place_outlined, text: preview.destination),
            _PreviewRow(
              icon: Icons.person_outline_rounded,
              text: 'Organized by ${preview.ownerName}',
            ),
            _PreviewRow(
              icon: Icons.calendar_today_outlined,
              text: '${_date(preview.startDate)} – ${_date(preview.endDate)}',
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onDecline,
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : onAccept,
                    child: const Text('Accept and join'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
