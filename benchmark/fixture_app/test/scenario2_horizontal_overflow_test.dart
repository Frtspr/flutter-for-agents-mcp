import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixture_app/src/scenario2_user_badge_row.dart';

void main() {
  testWidgets('Scenario 2: UserTransactionBadgeRow renders dynamic email without horizontal overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.0),
            child: Center(
              child: UserTransactionBadgeRow(),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(UserTransactionBadgeRow), findsOneWidget);
    expect(find.text(r'-$12,450.00 USD'), findsOneWidget);
  });
}
