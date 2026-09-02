class ExpenseSplit {
  const ExpenseSplit({
    required this.userId,
    required this.amountCents,
    required this.settled,
  });

  final String userId;
  final int amountCents;
  final bool settled;
}

class Expense {
  const Expense({
    required this.id,
    required this.tripId,
    required this.title,
    required this.amountCents,
    required this.paidBy,
    required this.splits,
    required this.createdAt,
    required this.version,
  });

  final String id;
  final String tripId;
  final String title;
  final int amountCents;
  final String paidBy;
  final List<ExpenseSplit> splits;
  final DateTime createdAt;
  final int version;

  String get formattedAmount => formatCents(amountCents);
}

class MemberBalance {
  const MemberBalance({required this.userId, required this.netCents});

  final String userId;
  final int netCents;

  bool get isOwedMoney => netCents > 0;
  bool get owesMoney => netCents < 0;
}

String formatCents(int cents) {
  final sign = cents < 0 ? '-' : '';
  final absolute = cents.abs();
  final whole = absolute ~/ 100;
  final decimal = (absolute % 100).toString().padLeft(2, '0');
  return '${sign}RM $whole.$decimal';
}

List<MemberBalance> calculateBalances(List<Expense> expenses) {
  final balances = <String, int>{};
  for (final expense in expenses) {
    balances.putIfAbsent(expense.paidBy, () => 0);
    for (final split in expense.splits) {
      balances.putIfAbsent(split.userId, () => 0);
      if (split.userId == expense.paidBy || split.settled) continue;
      balances[split.userId] = balances[split.userId]! - split.amountCents;
      balances[expense.paidBy] = balances[expense.paidBy]! + split.amountCents;
    }
  }
  return balances.entries
      .map((entry) => MemberBalance(userId: entry.key, netCents: entry.value))
      .toList(growable: false);
}

Map<String, int> splitEqually(int totalCents, List<String> userIds) {
  if (userIds.isEmpty) return const {};
  final base = totalCents ~/ userIds.length;
  var remainder = totalCents % userIds.length;
  return {
    for (final userId in userIds) userId: base + (remainder-- > 0 ? 1 : 0),
  };
}
