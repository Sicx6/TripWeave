import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/screens/auth_gate.dart';
import '../features/auth/presentation/screens/configuration_screen.dart';

class TripWeaveApp extends StatelessWidget {
  const TripWeaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TripWeave',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AppConfig.isSupabaseConfigured
          ? const AuthGate()
          : const ConfigurationScreen(),
    );
  }
}
