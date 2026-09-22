import 'dart:io';

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

    final receiptPaths = splitRows
        .map((row) => row['receipt_path'] as String?)
        .whereType<String>()
        .toList(growable: false);
    final signedReceiptUrls = receiptPaths.isEmpty
        ? <String, String>{}
        : {
            for (final signed in await _client.storage
                .from('expense-receipts')
                .createSignedUrlsResult(receiptPaths, 60 * 60))
              if (signed is SignedUrlSuccess) signed.path: signed.signedUrl,
          };

    return expenseRows.map((row) {
      final expenseId = row['id'] as String;
      return _mapExpense(
        row,
        splitRows.where((split) => split['expense_id'] == expenseId),
        signedReceiptUrls,
      );
    }).toList(growable: false);
  }

  @override
  Future<void> createExpense({
    required String tripId,
    required ExpenseDraft draft,
  }) async {
    final expenseId = _uuid.v4();
    await _client.rpc(
      'create_trip_expense',
      params: {
        'new_expense_id': expenseId,
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
  }

  @override
  Future<void> settleSplit({
    required String tripId,
    required String expenseId,
    required String userId,
    required String receiptImagePath,
  }) async {
    final receiptPath = await _uploadReceipt(
      tripId: tripId,
      expenseId: expenseId,
      userId: userId,
      imagePath: receiptImagePath,
    );
    await _client.rpc(
      'settle_expense_split',
      params: {
        'target_expense_id': expenseId,
        'target_user_id': userId,
        'receipt_storage_path': receiptPath,
      },
    );
  }

  @override
  Future<void> reviewPaymentProof({
    required String expenseId,
    required String userId,
    required bool approved,
    String? rejectionReason,
  }) =>
      _client.rpc(
        'review_expense_payment_proof',
        params: {
          'target_expense_id': expenseId,
          'target_user_id': userId,
          'approve_proof': approved,
          'rejection_reason': rejectionReason?.trim(),
        },
      );

  static Expense _mapExpense(
    Map<String, dynamic> row,
    Iterable<Map<String, dynamic>> splitRows,
    Map<String, String> signedReceiptUrls,
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
              proofStatus: PaymentProofStatus.fromDatabase(
                split['receipt_status'] as String?,
              ),
              receiptUrl: signedReceiptUrls[split['receipt_path'] as String?],
              rejectionReason: split['receipt_rejection_reason'] as String?,
            ),
          )
          .toList(growable: false),
      createdAt: DateTime.parse(row['created_at'] as String),
      version: row['version'] as int,
    );
  }

  Future<String?> _uploadReceipt({
    required String tripId,
    required String expenseId,
    required String userId,
    required String? imagePath,
  }) async {
    if (imagePath == null) return null;
    final extension = imagePath.split('.').last.toLowerCase();
    final path = '$tripId/$expenseId/$userId-receipt.$extension';
    await _client.storage.from('expense-receipts').upload(
          path,
          File(imagePath),
          fileOptions: const FileOptions(upsert: true),
        );
    return path;
  }

  static int _databaseMoneyToCents(Object? value) {
    final text = value is num ? value.toString() : value as String? ?? '0';
    return (num.parse(text) * 100).round();
  }
}
