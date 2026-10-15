import 'package:flutter_test/flutter_test.dart';

import 'scenario1_vertical_overflow_test.dart' as scenario1;
import 'scenario2_horizontal_overflow_test.dart' as scenario2;
import 'scenario3_pump_and_settle_timeout_test.dart' as scenario3;
import 'scenario4_missing_plugin_test.dart' as scenario4;

void main() {
  group('Chamber of Horrors Full Suite', () {
    group('Scenario 1: Vertical RenderFlex Overflow', scenario1.main);
    group('Scenario 2: Horizontal RenderFlex Overflow', scenario2.main);
    group('Scenario 3: pumpAndSettle Timeout', scenario3.main);
    group('Scenario 4: MissingPluginException', scenario4.main);
  });
}
