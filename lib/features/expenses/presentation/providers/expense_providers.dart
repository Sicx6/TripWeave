import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/supabase_expense_repository.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return SupabaseExpenseRepository(Supabase.instance.client);
});

final expenseListProvider =
    FutureProvider.autoDispose.family<List<Expense>, String>((ref, tripId) {
  return ref.watch(expenseRepositoryProvider).getExpenses(tripId);
});

final expenseBalanceProvider = Provider.autoDispose
    .family<AsyncValue<List<MemberBalance>>, String>((ref, tripId) {
  return ref.watch(expenseListProvider(tripId)).whenData(calculateBalances);
});

final expenseControllerProvider =
    AsyncNotifierProvider<ExpenseController, void>(ExpenseController.new);

class ExpenseController extends AsyncNotifier<void> {
  ExpenseRepository get _repository => ref.read(expenseRepositoryProvider);

  @override
  Future<void> build() async {}

  Future<bool> createExpense({
    required String tripId,
    required ExpenseDraft draft,
  }) =>
      _run(
        tripId,
        () => _repository.createExpense(tripId: tripId, draft: draft),
      );

  Future<bool> settle({
    required String tripId,
    required String expenseId,
    required String userId,
  }) =>
      _run(
        tripId,
        () => _repository.settleSplit(
          expenseId: expenseId,
          userId: userId,
        ),
      );

  Future<bool> _run(
    String tripId,
    Future<Object?> Function() operation,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(operation);
    if (!state.hasError) ref.invalidate(expenseListProvider(tripId));
    return !state.hasError;
  }
}
