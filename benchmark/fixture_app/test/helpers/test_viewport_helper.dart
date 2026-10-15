import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper to configure and safely reset test viewports in widget tests.
class TestViewportHelper {
  /// Sets a simulated viewport size for [tester] and registers automatic teardown reset.
  static void setViewport(
    WidgetTester tester, {
    required double width,
    required double height,
    double pixelRatio = 1.0,
  }) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = pixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Sets a realistic compact mobile viewport (360x480).
  static void setCompactMobile(WidgetTester tester) {
    setViewport(tester, width: 360, height: 480);
  }

  /// Sets a realistic standard mobile viewport (360x640).
  static void setStandardMobile(WidgetTester tester) {
    setViewport(tester, width: 360, height: 640);
  }
}
