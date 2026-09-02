import 'package:flutter_test/flutter_test.dart';
import 'package:tripweave/features/activities/domain/entities/activity_proposal.dart';

void main() {
  test('activity proposal calculates vote total and formats cost', () {
    final proposal = ActivityProposal(
      id: 'proposal-1',
      tripId: 'trip-1',
      proposedBy: 'user-1',
      title: 'Temple visit',
      category: 'Culture',
      submittedByName: 'Ikhwan',
      location: 'Kyoto',
      proposedAt: DateTime(2026, 10, 1, 10),
      estimatedCostCents: 125090,
      description: 'Morning visit',
      status: ProposalStatus.voting,
      yesVotes: 3,
      noVotes: 1,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
      version: 1,
    );

    expect(proposal.totalVotes, 4);
    expect(proposal.formattedCost, 'RM 1250.90');
  });

  test('custom proposal displays its user-defined category', () {
    final proposal = ActivityProposal(
      id: 'proposal-2',
      tripId: 'trip-1',
      proposedBy: 'user-1',
      submittedByName: 'Ikhwan',
      title: 'Sunrise photos',
      category: 'Custom',
      customCategory: 'Photography',
      location: 'Kyoto',
      proposedAt: DateTime(2026, 10, 1, 6),
      estimatedCostCents: 0,
      description: '',
      status: ProposalStatus.voting,
      yesVotes: 0,
      noVotes: 0,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
      version: 1,
    );

    expect(proposal.displayCategory, 'Photography');
  });
}
