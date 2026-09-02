import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripweave/features/auth/presentation/screens/configuration_screen.dart';

void main() {
  testWidgets('explains missing Supabase configuration', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ConfigurationScreen()));

    expect(find.textContaining('Supabase connection'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
  });
}
