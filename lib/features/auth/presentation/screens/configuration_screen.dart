import 'package:flutter/material.dart';

class ConfigurationScreen extends StatelessWidget {
  const ConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.route_rounded,
                  size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              Text('TripWeave needs its Supabase connection.',
                  style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 16),
              const Text(
                'Run the app with SUPABASE_URL and SUPABASE_ANON_KEY as '
                'compile-time values. The README contains the exact command.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
