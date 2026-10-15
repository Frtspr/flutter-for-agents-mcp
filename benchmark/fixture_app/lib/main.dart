import 'package:flutter/material.dart';
import 'src/scenario1_profile_card.dart';
import 'src/scenario2_user_badge_row.dart';
import 'src/scenario3_sync_status_spinner.dart';
import 'src/scenario4_cached_preferences.dart';

void main() {
  runApp(const ChamberOfHorrorsApp());
}

class ChamberOfHorrorsApp extends StatelessWidget {
  const ChamberOfHorrorsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chamber of Horrors Fixture App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Chamber of Horrors Showcase'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: const [
            Text(
              'Scenario 1: Profile Card',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            UserProfileCard(),
            Divider(height: 32),
            Text(
              'Scenario 2: User Badge Row',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            UserTransactionBadgeRow(),
            Divider(height: 32),
            Text(
              'Scenario 3: Sync Status Spinner',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            WorkspaceSyncStatusCard(isSyncing: true),
            Divider(height: 32),
            Text(
              'Scenario 4: Preferences Card',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            PreferencesThemeCard(),
          ],
        ),
      ),
    );
  }
}
