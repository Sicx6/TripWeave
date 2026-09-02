import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';

class SupabaseExpenseRepository implements ExpenseRepository {
  SupabaseExpenseRepository(this._client);

  final SupabaseClient _client;
  static const _uuid = Uuid();

  @override
  Future<List<Expense>> getExpenses(String tripId) async {
    final expenseRows = await _client
        .from('expenses')
        .select()
        .eq('trip_id', tripId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    if (expenseRows.isEmpty) return const [];

    final ids =
        expenseRows.map((row) => row['id'] as String).toList(growable: false);
    final splitRows = await _client
        .from('expense_splits')
        .select()
        .inFilter('expense_id', ids)
        .isFilter('deleted_at', null);

    return expenseRows.map((row) {
      final expenseId = row['id'] as String;
      return _mapExpense(
        row,
        splitRows.where((split) => split['expense_id'] == expenseId),
      );
    }).toList(growable: false);
  }

  @override
  Future<void> createExpense({
    required String tripId,
    required ExpenseDraft draft,
  }) =>
      _client.rpc(
        'create_trip_expense',
        params: {
          'new_expense_id': _uuid.v4(),
          'target_trip_id': tripId,
          'expense_title': draft.title.trim(),
          'amount_cents': draft.amountCents,
          'payer_id': draft.paidBy,
          'split_values': draft.splits.entries
              .map((entry) => {
                    'user_id': entry.key,
                    'amount_cents': entry.value,
                  })
              .toList(),
        },
      );

  @override
  Future<void> settleSplit({
    required String expenseId,
    required String userId,
  }) =>
      _client.rpc(
        'settle_expense_split',
        params: {'target_expense_id': expenseId, 'target_user_id': userId},
      );

  static Expense _mapExpense(
    Map<String, dynamic> row,
    Iterable<Map<String, dynamic>> splitRows,
  ) {
    return Expense(
      id: row['id'] as String,
      tripId: row['trip_id'] as String,
      title: row['title'] as String,
      amountCents: _databaseMoneyToCents(row['amount']),
      paidBy: row['paid_by'] as String,
      splits: splitRows
          .map(
            (split) => ExpenseSplit(
              userId: split['user_id'] as String,
              amountCents: _databaseMoneyToCents(split['amount']),
              settled: split['settled'] as bool,
            ),
          )
          .toList(growable: false),
      createdAt: DateTime.parse(row['created_at'] as String),
      version: row['version'] as int,
    );
  }

  static int _databaseMoneyToCents(Object? value) {
    final text = value is num ? value.toString() : value as String? ?? '0';
    return (num.parse(text) * 100).round();
  }
}
