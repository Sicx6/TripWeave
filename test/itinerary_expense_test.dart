import 'package:flutter_test/flutter_test.dart';
import 'package:tripweave/features/expenses/domain/entities/expense.dart';
import 'package:tripweave/features/itinerary/domain/entities/itinerary_item.dart';

void main() {
  test('detects overlapping scheduled itinerary items', () {
    final first = _item(
      id: 'one',
      start: DateTime(2026, 10, 1, 10),
      end: DateTime(2026, 10, 1, 12),
    );
    final second = _item(
      id: 'two',
      start: DateTime(2026, 10, 1, 11),
      end: DateTime(2026, 10, 1, 13),
    );

    expect(first.overlaps(second), isTrue);
  });

  test('equal split preserves every cent', () {
    final splits = splitEqually(1000, ['a', 'b', 'c']);

    expect(splits, {'a': 334, 'b': 333, 'c': 333});
    expect(splits.values.reduce((a, b) => a + b), 1000);
  });

  test('settled expense shares are excluded from balances', () {
    final expense = Expense(
      id: 'expense-1',
      tripId: 'trip-1',
      title: 'Dinner',
      amountCents: 3000,
      paidBy: 'owner',
      splits: const [
        ExpenseSplit(userId: 'owner', amountCents: 1000, settled: false),
        ExpenseSplit(userId: 'a', amountCents: 1000, settled: false),
        ExpenseSplit(userId: 'b', amountCents: 1000, settled: true),
      ],
      createdAt: DateTime(2026, 10, 1),
      version: 1,
    );
    final balances = calculateBalances([expense]);
    final byUser = {for (final item in balances) item.userId: item.netCents};

    expect(byUser['owner'], 1000);
    expect(byUser['a'], -1000);
    expect(byUser['b'], 0);
  });
}

ItineraryItem _item({
  required String id,
  required DateTime start,
  required DateTime end,
}) {
  return ItineraryItem(
    id: id,
    tripId: 'trip-1',
    title: id,
    location: 'Location',
    startAt: start,
    endAt: end,
    position: 0,
    status: ItineraryItemStatus.scheduled,
    version: 1,
  );
}
