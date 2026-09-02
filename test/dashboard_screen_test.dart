import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripweave/features/auth/domain/entities/app_user.dart';
import 'package:tripweave/features/auth/presentation/providers/auth_providers.dart';
import 'package:tripweave/core/theme/app_theme.dart';
import 'package:tripweave/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:tripweave/features/trips/presentation/providers/trip_providers.dart';

void main() {
  testWidgets('dashboard greets the user and shows the empty trip state',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(
            const AppUser(
              id: 'user-1',
              email: 'ikhwan@example.com',
              displayName: 'Ikhwan',
            ),
          ),
          tripListProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hello, Ikhwan'), findsOneWidget);
    expect(find.text('My Trips'), findsOneWidget);
    expect(find.text('Your next adventure starts here'), findsOneWidget);
    expect(find.text('Create your first trip'), findsOneWidget);
  });
}
