import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../members/domain/entities/trip_member.dart';
import '../../../members/presentation/providers/member_providers.dart';
import '../../../trips/domain/entities/trip.dart';
import '../../domain/entities/expense.dart';
import '../providers/expense_providers.dart';
import 'add_expense_screen.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({
    required this.trip,
    required this.currentUserId,
    required this.isOwner,
    super.key,
  });

  final Trip trip;
  final String currentUserId;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expenseListProvider(trip.id));
    final balances = ref.watch(expenseBalanceProvider(trip.id));
    final members = ref.watch(memberListProvider(trip.id));
    final memberValues = members.valueOrNull ?? const <TripMember>[];
    final names = {
      for (final member in memberValues) member.userId: member.displayName,
    };

    return RefreshIndicator(
      onRefresh: () => ref.refresh(expenseListProvider(trip.id).future),
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
                            Text('Expenses and balances',
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 4),
                            const Text(
                                'See who paid and what remains unsettled.'),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: memberValues.isEmpty
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AddExpenseScreen(
                                      trip: trip,
                                      members: memberValues,
                                      currentUserId: currentUserId,
                                      isOwner: isOwner,
                                    ),
                                  ),
                                ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text('Balances',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  balances.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) =>
                        Text('Unable to calculate balances: $error'),
                    data: (values) => values.isEmpty
                        ? const _NoBalances()
                        : Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: values
                                .map(
                                  (balance) => _BalanceCard(
                                    name:
                                        names[balance.userId] ?? 'Trip member',
                                    balance: balance,
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 28),
                  Text('Expense history',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  expenses.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) =>
                        Text('Unable to load expenses: $error'),
                    data: (items) => items.isEmpty
                        ? const _ExpenseEmpty()
                        : Column(
                            children: items
                                .map(
                                  (expense) => _ExpenseCard(
                                    expense: expense,
                                    names: names,
                                    currentUserId: currentUserId,
                                    isOwner: isOwner,
                                    onSettle: (userId) =>
                                        _settle(context, ref, expense, userId),
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

  Future<void> _settle(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
    String userId,
  ) async {
    final success = await ref.read(expenseControllerProvider.notifier).settle(
          tripId: trip.id,
          expenseId: expense.id,
          userId: userId,
        );
    if (!context.mounted || success) return;
    final error = ref.read(expenseControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error?.toString() ?? 'Unable to settle split.')),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.name, required this.balance});

  final String name;
  final MemberBalance balance;

  @override
  Widget build(BuildContext context) {
    final neutral = balance.netCents == 0;
    final color = neutral
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : balance.isOwedMoney
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error;
    return Container(
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E8E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(
            neutral
                ? 'Settled'
                : balance.isOwedMoney
                    ? 'Gets back ${formatCents(balance.netCents)}'
                    : 'Owes ${formatCents(balance.netCents.abs())}',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.names,
    required this.currentUserId,
    required this.isOwner,
    required this.onSettle,
  });

  final Expense expense;
  final Map<String, String> names;
  final String currentUserId;
  final bool isOwner;
  final ValueChanged<String> onSettle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: const CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
        title: Text(expense.title),
        subtitle: Text('Paid by ${names[expense.paidBy] ?? 'Trip member'}'),
        trailing: Text(
          expense.formattedAmount,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        children: expense.splits.map((split) {
          final isPayer = split.userId == expense.paidBy;
          final canSettle = !isPayer &&
              !split.settled &&
              (split.userId == currentUserId ||
                  expense.paidBy == currentUserId ||
                  isOwner);
          return ListTile(
            title: Text(names[split.userId] ?? 'Trip member'),
            subtitle: Text(
              isPayer
                  ? 'Payer share'
                  : split.settled
                      ? 'Settled'
                      : 'Unsettled',
            ),
            trailing: canSettle
                ? TextButton(
                    onPressed: () => onSettle(split.userId),
                    child: Text('Settle ${formatCents(split.amountCents)}'),
                  )
                : Text(formatCents(split.amountCents)),
          );
        }).toList(),
      ),
    );
  }
}

class _NoBalances extends StatelessWidget {
  const _NoBalances();

  @override
  Widget build(BuildContext context) {
    return const Text('No outstanding balances.');
  }
}

class _ExpenseEmpty extends StatelessWidget {
  const _ExpenseEmpty();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No expenses recorded yet.')),
      ),
    );
  }
}
