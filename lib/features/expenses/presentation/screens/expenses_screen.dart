import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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
    final budget = ref.watch(
      expenseBudgetProvider(
        (tripId: trip.id, budgetCents: trip.budgetCents),
      ),
    );
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
                  budget.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) =>
                        Text('Unable to calculate trip budget: $error'),
                    data: (summary) => _BudgetCard(summary: summary),
                  ),
                  const SizedBox(height: 28),
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
                                    onReview: (userId, approved) => _review(
                                      context,
                                      ref,
                                      expense,
                                      userId,
                                      approved,
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

  Future<void> _settle(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
    String userId,
  ) async {
    final receipt = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (!context.mounted || receipt == null) return;
    final success = await ref.read(expenseControllerProvider.notifier).settle(
          tripId: trip.id,
          expenseId: expense.id,
          userId: userId,
          receiptImagePath: receipt.path,
        );
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt sent for review.')),
      );
      return;
    }
    final error = ref.read(expenseControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error?.toString() ?? 'Unable to settle split.')),
    );
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
    String userId,
    bool approved,
  ) async {
    String? reason;
    if (!approved) {
      reason = await _askForRejectionReason(context);
      if (reason == null || !context.mounted) return;
    }
    final success =
        await ref.read(expenseControllerProvider.notifier).reviewPaymentProof(
              tripId: trip.id,
              expenseId: expense.id,
              userId: userId,
              approved: approved,
              rejectionReason: reason,
            );
    if (!context.mounted) return;
    final message = success
        ? approved
            ? 'Payment approved.'
            : 'Receipt rejected. The member can upload a new one.'
        : ref.read(expenseControllerProvider).error?.toString() ??
            'Unable to review payment proof.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _askForRejectionReason(BuildContext context) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject receipt?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'For example: amount is not visible',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isNotEmpty) Navigator.pop(dialogContext, reason);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.summary});

  final TripBudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    final hasBudget = summary.budgetCents > 0;
    final progress = summary.progress.clamp(0.0, 1.0);
    final color = summary.isOverBudget
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.donut_large_rounded),
                const SizedBox(width: 10),
                Text('Trip budget',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '${formatCents(summary.recordedCents)} recorded of '
              '${formatCents(summary.budgetCents)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: hasBudget ? progress : 0,
              color: color,
              minHeight: 8,
              borderRadius: BorderRadius.circular(99),
            ),
            const SizedBox(height: 10),
            Text(
              !hasBudget
                  ? 'Set a trip budget to start tracking spending.'
                  : summary.isOverBudget
                      ? '${formatCents(summary.remainingCents.abs())} over budget'
                      : '${formatCents(summary.remainingCents)} remaining',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
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
    required this.onReview,
  });

  final Expense expense;
  final Map<String, String> names;
  final String currentUserId;
  final bool isOwner;
  final ValueChanged<String> onSettle;
  final void Function(String userId, bool approved) onReview;

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
        children: [
          ...expense.splits.map((split) {
            final isPayer = split.userId == expense.paidBy;
            final canUpload = !isPayer &&
                split.canUploadReceipt &&
                (split.userId == currentUserId ||
                    expense.paidBy == currentUserId ||
                    isOwner);
            final canReview = !isPayer &&
                split.proofStatus == PaymentProofStatus.pending &&
                (expense.paidBy == currentUserId || isOwner);
            return ListTile(
              title: Text(names[split.userId] ?? 'Trip member'),
              subtitle: Text(
                isPayer ? 'Payer share' : _splitDescription(split),
              ),
              trailing: canUpload
                  ? TextButton.icon(
                      onPressed: () => onSettle(split.userId),
                      icon: const Icon(Icons.upload_file_rounded),
                      label: Text(
                        split.proofStatus == PaymentProofStatus.rejected
                            ? 'Replace receipt'
                            : 'Pay ${formatCents(split.amountCents)}',
                      ),
                    )
                  : canReview
                      ? PopupMenuButton<bool>(
                          tooltip: 'Review receipt',
                          onSelected: (approved) =>
                              onReview(split.userId, approved),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: true,
                              child: Text('Approve payment'),
                            ),
                            PopupMenuItem(
                              value: false,
                              child: Text('Reject receipt'),
                            ),
                          ],
                        )
                      : Text(formatCents(split.amountCents)),
              isThreeLine: split.receiptUrl != null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              onTap: split.receiptUrl == null
                  ? null
                  : () => showDialog<void>(
                        context: context,
                        builder: (_) => Dialog(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              split.receiptUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text(
                                  'Receipt preview is unavailable right now.',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
            );
          }),
        ],
      ),
    );
  }

  static String _splitDescription(ExpenseSplit split) {
    if (split.proofStatus == PaymentProofStatus.rejected &&
        split.rejectionReason?.isNotEmpty == true) {
      return 'Receipt rejected: ${split.rejectionReason}';
    }
    if (split.settled && split.receiptUrl == null) {
      return 'Settled without receipt proof';
    }
    return split.proofStatus.label;
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
