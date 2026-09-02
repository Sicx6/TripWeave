import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../../members/domain/entities/trip_member.dart';
import '../../../trips/domain/entities/trip.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';
import '../providers/expense_providers.dart';

enum _SplitMode { equal, custom }

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({
    required this.trip,
    required this.members,
    required this.currentUserId,
    required this.isOwner,
    super.key,
  });

  final Trip trip;
  final List<TripMember> members;
  final String currentUserId;
  final bool isOwner;

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  late String _paidBy;
  _SplitMode _mode = _SplitMode.equal;
  late final Map<String, bool> _selected;
  late final Map<String, TextEditingController> _customAmounts;

  @override
  void initState() {
    super.initState();
    _paidBy = widget.currentUserId;
    _selected = {for (final member in widget.members) member.userId: true};
    _customAmounts = {
      for (final member in widget.members)
        member.userId: TextEditingController(text: '0.00'),
    };
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    for (final controller in _customAmounts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final operation = ref.watch(expenseControllerProvider);
    final payerChoices = widget.isOwner
        ? widget.members
        : widget.members
            .where((member) => member.userId == widget.currentUserId)
            .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Add expense')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Record a group expense',
                        style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose who paid and exactly how the amount is shared.',
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: 'Expense title',
                        hintText: 'Example: Dinner',
                      ),
                      validator: (value) => (value?.trim().length ?? 0) < 2
                          ? 'Enter an expense title'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Total amount',
                        prefixText: 'RM ',
                      ),
                      validator: (value) {
                        final cents = parseMoneyToCents(value ?? '');
                        return cents == null || cents <= 0
                            ? 'Enter an amount greater than zero'
                            : null;
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _paidBy,
                      decoration: const InputDecoration(labelText: 'Paid by'),
                      items: payerChoices
                          .map((member) => DropdownMenuItem(
                                value: member.userId,
                                child: Text(member.displayName),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _paidBy = value ?? _paidBy),
                    ),
                    const SizedBox(height: 22),
                    Text('Split method',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    SegmentedButton<_SplitMode>(
                      segments: const [
                        ButtonSegment(
                          value: _SplitMode.equal,
                          label: Text('Equal'),
                          icon: Icon(Icons.balance_outlined),
                        ),
                        ButtonSegment(
                          value: _SplitMode.custom,
                          label: Text('Custom'),
                          icon: Icon(Icons.tune_rounded),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (values) =>
                          setState(() => _mode = values.first),
                    ),
                    const SizedBox(height: 14),
                    ...widget.members.map((member) {
                      final selected = _selected[member.userId] ?? false;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: selected,
                                onChanged: (value) => setState(
                                  () =>
                                      _selected[member.userId] = value ?? false,
                                ),
                              ),
                              Expanded(child: Text(member.displayName)),
                              if (_mode == _SplitMode.custom && selected)
                                SizedBox(
                                  width: 120,
                                  child: TextFormField(
                                    controller: _customAmounts[member.userId],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: const InputDecoration(
                                        prefixText: 'RM '),
                                    validator: (value) => parseMoneyToCents(
                                              value ?? '',
                                            ) ==
                                            null
                                        ? 'Invalid'
                                        : null,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: operation.isLoading ? null : _save,
                        child: operation.isLoading
                            ? const SizedBox.square(
                                dimension: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save expense'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final participants = _selected.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
    if (participants.isEmpty) {
      _message('Select at least one participant.');
      return;
    }
    final total = parseMoneyToCents(_amount.text)!;
    final splits = _mode == _SplitMode.equal
        ? splitEqually(total, participants)
        : {
            for (final userId in participants)
              userId: parseMoneyToCents(_customAmounts[userId]!.text)!,
          };
    if (splits.values.fold<int>(0, (sum, value) => sum + value) != total) {
      _message('Custom splits must add up exactly to the total amount.');
      return;
    }
    final draft = ExpenseDraft(
      title: _title.text,
      amountCents: total,
      paidBy: _paidBy,
      splits: splits,
    );
    final success = await ref
        .read(expenseControllerProvider.notifier)
        .createExpense(tripId: widget.trip.id, draft: draft);
    if (!mounted) return;
    if (!success) {
      _message(
        ref.read(expenseControllerProvider).error?.toString() ??
            'Unable to save expense.',
      );
      return;
    }
    Navigator.of(context).pop();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
