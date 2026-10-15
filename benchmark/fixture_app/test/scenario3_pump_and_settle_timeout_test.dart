import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixture_app/src/scenario3_sync_status_spinner.dart';

void main() {
  testWidgets('Scenario 3: WorkspaceSyncStatusCard pumpAndSettle timeout doom-loop', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WorkspaceSyncStatusCard(
            isSyncing: true,
            statusText: 'Synchronizing workspace models with remote cloud...',
          ),
        ),
      ),
    );

    // HORROR: pumpAndSettle called on active indeterminate CircularProgressIndicator
    await tester.pumpAndSettle();

    expect(find.text('Synchronizing workspace models with remote cloud...'), findsOneWidget);
  });
}
