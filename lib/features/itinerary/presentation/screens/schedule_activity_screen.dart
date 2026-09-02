import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../activities/domain/entities/activity_proposal.dart';
import '../../../trips/domain/entities/trip.dart';
import '../providers/itinerary_providers.dart';

class ScheduleActivityScreen extends ConsumerStatefulWidget {
  const ScheduleActivityScreen({
    required this.trip,
    required this.approvedProposals,
    super.key,
  });

  final Trip trip;
  final List<ActivityProposal> approvedProposals;

  @override
  ConsumerState<ScheduleActivityScreen> createState() =>
      _ScheduleActivityScreenState();
}

class _ScheduleActivityScreenState
    extends ConsumerState<ScheduleActivityScreen> {
  late ActivityProposal _proposal;
  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  @override
  void initState() {
    super.initState();
    _proposal = widget.approvedProposals.first;
    _setTimesFromProposal(_proposal);
  }

  void _setTimesFromProposal(ActivityProposal proposal) {
    final proposed = proposal.proposedAt;
    final tripStart = DateUtils.dateOnly(widget.trip.startDate);
    final tripEnd = DateUtils.dateOnly(widget.trip.endDate);
    final proposedDate = DateUtils.dateOnly(proposed);
    _date = proposedDate.isBefore(tripStart)
        ? tripStart
        : proposedDate.isAfter(tripEnd)
            ? tripEnd
            : proposedDate;
    _startTime = TimeOfDay.fromDateTime(proposed);
    _endTime = TimeOfDay.fromDateTime(proposed.add(const Duration(hours: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final operation = ref.watch(itineraryControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Add to itinerary')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Schedule an approved idea',
                      style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose when this activity should appear in the shared plan.',
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<ActivityProposal>(
                    value: _proposal,
                    decoration: const InputDecoration(labelText: 'Activity'),
                    items: widget.approvedProposals
                        .map((proposal) => DropdownMenuItem(
                              value: proposal,
                              child: Text(
                                proposal.title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (proposal) {
                      if (proposal == null) return;
                      setState(() {
                        _proposal = proposal;
                        _setTimesFromProposal(proposal);
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  _ScheduleField(
                    label: 'Date',
                    value: _formatDate(_date),
                    icon: Icons.calendar_today_outlined,
                    onTap: _chooseDate,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ScheduleField(
                          label: 'Start',
                          value: _startTime.format(context),
                          icon: Icons.schedule_outlined,
                          onTap: _chooseStart,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ScheduleField(
                          label: 'End',
                          value: _endTime.format(context),
                          icon: Icons.schedule_rounded,
                          onTap: _chooseEnd,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: operation.isLoading ? null : _save,
                      child: operation.isLoading
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Add to itinerary'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _chooseDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateUtils.dateOnly(widget.trip.startDate),
      lastDate: DateUtils.dateOnly(widget.trip.endDate),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _chooseStart() async {
    final value =
        await showTimePicker(context: context, initialTime: _startTime);
    if (value != null) setState(() => _startTime = value);
  }

  Future<void> _chooseEnd() async {
    final value = await showTimePicker(context: context, initialTime: _endTime);
    if (value != null) setState(() => _endTime = value);
  }

  Future<void> _save() async {
    final startAt = _combine(_date, _startTime);
    final endAt = _combine(_date, _endTime);
    if (!endAt.isAfter(startAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }
    final success =
        await ref.read(itineraryControllerProvider.notifier).addProposal(
              tripId: widget.trip.id,
              proposalId: _proposal.id,
              startAt: startAt,
              endAt: endAt,
            );
    if (!mounted) return;
    if (!success) {
      final error = ref.read(itineraryControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error?.toString() ?? 'Unable to schedule activity.')),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  static DateTime _combine(DateTime date, TimeOfDay time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _ScheduleField extends StatelessWidget {
  const _ScheduleField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        child: Text(value),
      ),
    );
  }
}
