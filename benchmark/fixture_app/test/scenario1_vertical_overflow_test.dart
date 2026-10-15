import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixture_app/src/scenario1_profile_card.dart';

void main() {
  testWidgets('Scenario 1: UserProfileCard renders without vertical overflow', (WidgetTester tester) async {
    // Constrain viewport to realistic compact mobile screen (360x480)
    tester.view.physicalSize = const Size(360, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 440,
              child: UserProfileCard(),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(UserProfileCard), findsOneWidget);
    expect(find.text('Save Profile'), findsOneWidget);
  });
}
