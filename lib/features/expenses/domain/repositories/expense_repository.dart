import '../entities/expense.dart';

class ExpenseDraft {
  const ExpenseDraft({
    required this.title,
    required this.amountCents,
    required this.paidBy,
    required this.splits,
  });

  final String title;
  final int amountCents;
  final String paidBy;
  final Map<String, int> splits;
}

abstract interface class ExpenseRepository {
  Future<List<Expense>> getExpenses(String tripId);
  Future<void> createExpense({
    required String tripId,
    required ExpenseDraft draft,
  });
  Future<void> settleSplit({
    required String expenseId,
    required String userId,
  });
}
