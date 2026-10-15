import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixture_app/src/scenario4_cached_preferences.dart';

void main() {
  testWidgets('Scenario 4: PreferencesThemeCard unmocked platform channel doom-loop', (WidgetTester tester) async {
    // HORROR: SharedPreferences.setMockInitialValues({}) was deliberately omitted!
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PreferencesThemeCard(),
        ),
      ),
    );

    // Triggers initState() -> SharedPreferences.getInstance()
    await tester.pump();

    expect(find.text('Current Active Theme: Dark Indigo (Default)'), findsOneWidget);
  });
}
