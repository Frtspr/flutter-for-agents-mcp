import 'package:flutter_sanity_mcp/src/heuristics.dart';
import 'package:flutter_sanity_mcp/src/loop_breaker.dart';
import 'package:test/test.dart';

void main() {
  group('Failure Fingerprint & Line Quantization', () {
    test('quantizeLine groups line numbers in buckets of 5', () {
      expect(LoopBreaker.quantizeLine(null), equals(0));
      expect(LoopBreaker.quantizeLine(0), equals(0));
      expect(LoopBreaker.quantizeLine(-5), equals(0));

      expect(LoopBreaker.quantizeLine(1), equals(0));
      expect(LoopBreaker.quantizeLine(4), equals(0));

      expect(LoopBreaker.quantizeLine(5), equals(5));
      expect(LoopBreaker.quantizeLine(9), equals(5));

      expect(LoopBreaker.quantizeLine(20), equals(20));
      expect(LoopBreaker.quantizeLine(21), equals(20));
      expect(LoopBreaker.quantizeLine(22), equals(20));
      expect(LoopBreaker.quantizeLine(23), equals(20));
      expect(LoopBreaker.quantizeLine(24), equals(20));

      expect(LoopBreaker.quantizeLine(25), equals(25));
      expect(LoopBreaker.quantizeLine(29), equals(25));
      expect(LoopBreaker.quantizeLine(30), equals(30));
    });

    test(
        'fingerprint hash remains stable across slight line shifts within bucket',
        () {
      final hash1 = LoopBreaker.computeFingerprintHash(
        category: 'renderFlexOverflowHorizontal',
        filePath: 'lib/src/widgets/user_row.dart',
        line: 21,
        errorSignature: 'renderflex overflowed on the right',
      );

      final hash2 = LoopBreaker.computeFingerprintHash(
        category: 'renderFlexOverflowHorizontal',
        filePath: 'lib/src/widgets/user_row.dart',
        line: 24, // Shifted by 3 lines due to an edit
        errorSignature: 'renderflex overflowed on the right',
      );

      expect(hash1, equals(hash2));
    });

    test('fingerprint hash changes when line shift crosses bucket threshold',
        () {
      final hash1 = LoopBreaker.computeFingerprintHash(
        category: 'renderFlexOverflowHorizontal',
        filePath: 'lib/src/widgets/user_row.dart',
        line: 21,
        errorSignature: 'renderflex overflowed on the right',
      );

      final hash3 = LoopBreaker.computeFingerprintHash(
        category: 'renderFlexOverflowHorizontal',
        filePath: 'lib/src/widgets/user_row.dart',
        line: 35, // Moved to a different widget/line
        errorSignature: 'renderflex overflowed on the right',
      );

      expect(hash1, isNot(equals(hash3)));
    });

    test('fingerprint normalizes file paths across separators and casing', () {
      final hashWindows = LoopBreaker.computeFingerprintHash(
        category: 'missingPlugin',
        filePath: r'C:\Users\Developer\App\lib\main.dart',
        line: 12,
        errorSignature: 'missingpluginexception',
      );

      final hashPosix = LoopBreaker.computeFingerprintHash(
        category: 'missingPlugin',
        filePath: 'c:/users/developer/app/lib/main.dart',
        line: 12,
        errorSignature: 'missingpluginexception',
      );

      final hashFileUri = LoopBreaker.computeFingerprintHash(
        category: 'missingPlugin',
        filePath: 'file:///c:/users/developer/app/lib/main.dart',
        line: 12,
        errorSignature: 'missingpluginexception',
      );

      expect(hashWindows, equals(hashPosix));
      expect(hashPosix, equals(hashFileUri));
    });

    test('fingerprint normalizes variable pixel count in RenderFlex signatures',
        () {
      final sig1 = LoopBreaker.normalizeSignature(
        'A RenderFlex overflowed by 24.0 pixels on the right.',
      );
      final sig2 = LoopBreaker.normalizeSignature(
        'A RenderFlex overflowed by 38.5 pixels on the right.',
      );

      expect(
          sig1, equals('a renderflex overflowed by [px] pixels on the right.'));
      expect(
          sig2, equals('a renderflex overflowed by [px] pixels on the right.'));
      expect(sig1, equals(sig2));

      final hash1 = LoopBreaker.computeFingerprintHash(
        category: 'renderFlexOverflowHorizontal',
        filePath: 'lib/row.dart',
        line: 10,
        errorSignature: sig1,
      );
      final hash2 = LoopBreaker.computeFingerprintHash(
        category: 'renderFlexOverflowHorizontal',
        filePath: 'lib/row.dart',
        line: 10,
        errorSignature: sig2,
      );

      expect(hash1, equals(hash2));
    });
  });

  group(
      'Consecutive Failure Escalation (Normal -> Guardrail -> Circuit Breaker)',
      () {
    late LoopBreaker breaker;
    late FailureFingerprint testFingerprint;

    setUp(() {
      breaker = LoopBreaker();
      testFingerprint = LoopBreaker.createFingerprint(
        category: 'renderFlexOverflowVertical',
        filePath: 'lib/screens/login.dart',
        line: 42,
        errorSignature: 'renderflex overflowed on the bottom',
      );
    });

    test('1st failure: normal clean output without guardrail banners', () {
      final directive = Heuristics.renderFlexVertical();
      final decision = breaker.recordFailure(
        fingerprint: testFingerprint,
        directive: directive,
        rawOutput: 'Error: RenderFlex overflowed by 15.0 pixels on the bottom.',
      );

      expect(decision.level, equals(BreakerLevel.normal));
      expect(decision.consecutiveMatches, equals(1));
      expect(decision.isGuardrail, isFalse);
      expect(decision.isTripped, isFalse);
      expect(decision.shouldHalt, isFalse);
      expect(decision.banner, isNull);
      expect(
        decision.formattedOutput,
        equals('Error: RenderFlex overflowed by 15.0 pixels on the bottom.'),
      );
      expect(breaker.currentLevel, equals(BreakerLevel.normal));
      expect(breaker.consecutiveFailures, equals(1));
    });

    test(
        '2nd consecutive match: injects GUARDRAIL_WARNING with heuristic directive',
        () {
      final directive = Heuristics.renderFlexVertical();

      // 1st failure
      breaker.recordFailure(
        fingerprint: testFingerprint,
        directive: directive,
        rawOutput: 'Error 1',
      );

      // 2nd consecutive failure
      final decision2 = breaker.recordFailure(
        fingerprint: testFingerprint,
        directive: directive,
        rawOutput: 'Error 2',
      );

      expect(decision2.level, equals(BreakerLevel.guardrailWarning));
      expect(decision2.consecutiveMatches, equals(2));
      expect(decision2.isGuardrail, isTrue);
      expect(decision2.isTripped, isFalse);
      expect(decision2.shouldHalt, isFalse);

      expect(decision2.banner, isNotNull);
      expect(decision2.banner, contains('[GUARDRAIL_WARNING]'));
      expect(
          decision2.banner, contains('Repeated failure detected (attempt #2)'));
      expect(decision2.banner, contains(testFingerprint.hash));
      expect(decision2.banner, contains('SingleChildScrollView'));

      expect(decision2.formattedOutput, contains('[GUARDRAIL_WARNING]'));
      expect(decision2.formattedOutput, contains('Error 2'));
      expect(breaker.isGuardrail, isTrue);
    });

    test(
        '3rd consecutive match: trips CIRCUIT_BREAKER_TRIPPED with strict stop instructions',
        () {
      final directive = Heuristics.renderFlexVertical();

      // 1st failure
      breaker.recordFailure(fingerprint: testFingerprint, directive: directive);
      // 2nd failure
      breaker.recordFailure(fingerprint: testFingerprint, directive: directive);
      // 3rd failure
      final decision3 = breaker.recordFailure(
        fingerprint: testFingerprint,
        directive: directive,
        rawOutput: 'Error 3',
      );

      expect(decision3.level, equals(BreakerLevel.circuitBreakerTripped));
      expect(decision3.consecutiveMatches, equals(3));
      expect(decision3.isGuardrail, isFalse);
      expect(decision3.isTripped, isTrue);
      expect(decision3.shouldHalt, isTrue);

      expect(decision3.banner, isNotNull);
      expect(decision3.banner, contains('[CIRCUIT_BREAKER_TRIPPED]'));
      expect(
          decision3.banner,
          contains(
              'Circuit breaker tripped! 3 consecutive identical failures.'));
      expect(decision3.banner, contains('STRICT STOP-EDITING INSTRUCTIONS:'));
      expect(
          decision3.banner, contains('STOP making blind code modifications'));
      expect(decision3.banner, contains('DO NOT retry the previous edit'));

      expect(decision3.formattedOutput, contains('[CIRCUIT_BREAKER_TRIPPED]'));
      expect(breaker.isTripped, isTrue);
    });

    test('subsequent failures stay in circuitBreakerTripped state', () {
      final directive = Heuristics.renderFlexVertical();

      for (var i = 1; i <= 5; i++) {
        breaker.recordFailure(
            fingerprint: testFingerprint, directive: directive);
      }

      expect(breaker.currentLevel, equals(BreakerLevel.circuitBreakerTripped));
      expect(breaker.consecutiveFailures, equals(5));
      expect(breaker.isTripped, isTrue);
    });

    test('different failure resets consecutive matches counter', () {
      final directive = Heuristics.renderFlexVertical();

      final differentFingerprint = LoopBreaker.createFingerprint(
        category: 'pumpAndSettleTimeout',
        filePath: 'test/login_test.dart',
        line: 80,
        errorSignature: 'pumpandsettle timed out',
      );

      // Attempt 1 with F1
      breaker.recordFailure(fingerprint: testFingerprint, directive: directive);
      expect(breaker.consecutiveFailures, equals(1));

      // Attempt 2 with F2 (different fingerprint)
      final decisionF2 = breaker.recordFailure(
        fingerprint: differentFingerprint,
        directive: Heuristics.pumpAndSettleTimeout(),
      );

      expect(decisionF2.level, equals(BreakerLevel.normal));
      expect(decisionF2.consecutiveMatches, equals(1));
      expect(breaker.consecutiveFailures, equals(1));
      expect(breaker.currentLevel, equals(BreakerLevel.normal));

      // Attempt 3 with F2 again -> escalates to Guardrail
      final decisionF2Repeat = breaker.recordFailure(
        fingerprint: differentFingerprint,
        directive: Heuristics.pumpAndSettleTimeout(),
      );
      expect(decisionF2Repeat.level, equals(BreakerLevel.guardrailWarning));
      expect(decisionF2Repeat.consecutiveMatches, equals(2));
    });
  });

  group('Reset on Success', () {
    late LoopBreaker breaker;
    late FailureFingerprint testFingerprint;

    setUp(() {
      breaker = LoopBreaker();
      testFingerprint = LoopBreaker.createFingerprint(
        category: 'renderFlexOverflowHorizontal',
        filePath: 'lib/my_row.dart',
        line: 15,
        errorSignature: 'renderflex overflowed on the right',
      );
    });

    test('recordSuccess resets consecutive failures, history, and level', () {
      // 1st failure (normal)
      breaker.recordFailure(fingerprint: testFingerprint);
      // 2nd failure (guardrail)
      breaker.recordFailure(fingerprint: testFingerprint);
      expect(breaker.isGuardrail, isTrue);
      expect(breaker.consecutiveFailures, equals(2));

      // Test passes!
      breaker.recordSuccess();

      expect(breaker.consecutiveFailures, equals(0));
      expect(breaker.currentLevel, equals(BreakerLevel.normal));
      expect(breaker.lastFingerprint, isNull);
      expect(breaker.history, isEmpty);

      // Next failure starts fresh at 1st failure (normal)
      final decision = breaker.recordFailure(fingerprint: testFingerprint);
      expect(decision.level, equals(BreakerLevel.normal));
      expect(decision.consecutiveMatches, equals(1));
      expect(decision.banner, isNull);
    });

    test('reset() behaves identically to recordSuccess()', () {
      breaker.recordFailure(fingerprint: testFingerprint);
      breaker.recordFailure(fingerprint: testFingerprint);
      breaker.recordFailure(fingerprint: testFingerprint);
      expect(breaker.isTripped, isTrue);

      breaker.reset();

      expect(breaker.isTripped, isFalse);
      expect(breaker.consecutiveFailures, equals(0));
      expect(breaker.history, isEmpty);
    });
  });

  group('Heuristic Directives Detection & Selection', () {
    test(
        'detects Horizontal RenderFlex overflow in Row with actionable directives',
        () {
      const output = '''
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 28.0 pixels on the right.

The relevant error-causing widget was:
  Row file:///C:/workspace/lib/screens/profile_screen.dart:52:14
''';

      final directive = Heuristics.detect(output);

      expect(directive, isNotNull);
      expect(directive!.category,
          equals(FailureCategory.renderFlexOverflowHorizontal));
      expect(directive.title, equals('RenderFlex Horizontal Overflow'));
      expect(
        directive.actionableFixes
            .any((fix) => fix.contains('Expanded') || fix.contains('Flexible')),
        isTrue,
      );
      expect(
        directive.actionableFixes
            .any((fix) => fix.contains('SingleChildScrollView')),
        isTrue,
      );
      expect(
        directive.actionableFixes.any((fix) => fix.contains('Wrap')),
        isTrue,
      );
      expect(directive.codeSnippet, contains('Wrap('));
    });

    test(
        'detects Vertical RenderFlex overflow in Column with actionable directives',
        () {
      const output = '''
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 45.2 pixels on the bottom.

The relevant error-causing widget was:
  Column file:///C:/workspace/lib/screens/dashboard.dart:33:10
''';

      final directive = Heuristics.detect(output);

      expect(directive, isNotNull);
      expect(directive!.category,
          equals(FailureCategory.renderFlexOverflowVertical));
      expect(directive.title, equals('RenderFlex Vertical Overflow'));
      expect(
        directive.actionableFixes.any((fix) => fix.contains('Expanded')),
        isTrue,
      );
      expect(
        directive.actionableFixes
            .any((fix) => fix.contains('SingleChildScrollView')),
        isTrue,
      );
      expect(
        directive.actionableFixes.any((fix) => fix.contains('ListView')),
        isTrue,
      );
      expect(directive.codeSnippet, contains('ListView'));
    });

    test(
        'detects Unbounded constraints in ListView with shrinkWrap and Expanded directives',
        () {
      const output = '''
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performResize():
Vertical viewport was given unbounded height.
Viewports expand in the scrolling direction to fill their container...
The relevant error-causing widget was:
  ListView file:///C:/workspace/lib/widgets/item_list.dart:77:12
''';

      final directive = Heuristics.detect(output);

      expect(directive, isNotNull);
      expect(directive!.category, equals(FailureCategory.unboundedConstraints));
      expect(directive.title,
          contains('Unbounded Viewport / ListView Constraints'));
      expect(
        directive.actionableFixes.any((fix) => fix.contains('Expanded')),
        isTrue,
      );
      expect(
        directive.actionableFixes
            .any((fix) => fix.contains('shrinkWrap: true')),
        isTrue,
      );
      expect(
        directive.actionableFixes
            .any((fix) => fix.contains('NeverScrollableScrollPhysics')),
        isTrue,
      );
      expect(directive.codeSnippet, contains('shrinkWrap: true'));
    });

    test('detects pumpAndSettle timed out with discrete pump directives', () {
      const output = '''
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following FlutterError was thrown running a test:
pumpAndSettle timed out after 10:00.000000: Frame scheduled, but not rendered.
''';

      final directive = Heuristics.detect(output);

      expect(directive, isNotNull);
      expect(directive!.category, equals(FailureCategory.pumpAndSettleTimeout));
      expect(directive.title, equals('pumpAndSettle Timed Out'));
      expect(
        directive.actionableFixes.any((fix) => fix.contains('tester.pump()')),
        isTrue,
      );
      expect(
        directive.actionableFixes
            .any((fix) => fix.contains('CircularProgressIndicator')),
        isTrue,
      );
      expect(directive.codeSnippet, contains('await tester.pump('));
    });

    test(
        'detects MissingPluginException and formulates platform channel mock directives',
        () {
      const output = '''
MissingPluginException(No implementation found for method getApplicationDocumentsDirectory on channel plugins.flutter.io/path_provider)
''';

      final directive = Heuristics.detect(output);

      expect(directive, isNotNull);
      expect(directive!.category, equals(FailureCategory.missingPlugin));
      expect(directive.title, contains('MissingPluginException'));
      expect(
        directive.actionableFixes
            .any((fix) => fix.contains('setMockMethodCallHandler')),
        isTrue,
      );
      expect(
        directive.actionableFixes.any(
            (fix) => fix.contains('SharedPreferences.setMockInitialValues')),
        isTrue,
      );
      expect(
        directive.codeSnippet,
        contains(
            'TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger'),
      );
      expect(
          directive.codeSnippet, contains('plugins.flutter.io/path_provider'));
      expect(
          directive.codeSnippet, contains('getApplicationDocumentsDirectory'));
    });
  });

  group('End-to-End Processing (LoopBreaker.processOutput)', () {
    test(
        'parses location, selects heuristics, and trips circuit breaker after 3 runs',
        () {
      final breaker = LoopBreaker();

      const failureLog = '''
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 25.0 pixels on the bottom.

The relevant error-causing widget was:
  Column file:///C:/workspace/lib/screens/login_screen.dart:42:10
''';

      // Run 1: 1st failure -> normal
      final d1 = breaker.processOutput(failureLog);
      expect(d1.level, equals(BreakerLevel.normal));
      expect(d1.consecutiveMatches, equals(1));
      expect(d1.banner, isNull);
      expect(d1.fingerprint.quantizedLine, equals(40)); // 42 quantized to 40
      expect(d1.fingerprint.normalizedFilePath, contains('login_screen.dart'));

      // Run 2: slight edit shifted line from 42 to 44 (same bucket 40)
      const failureLogSlightShift = '''
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 22.0 pixels on the bottom.

The relevant error-causing widget was:
  Column file:///C:/workspace/lib/screens/login_screen.dart:44:10
''';

      final d2 = breaker.processOutput(failureLogSlightShift);
      expect(d2.level, equals(BreakerLevel.guardrailWarning));
      expect(d2.consecutiveMatches, equals(2));
      expect(d2.banner, isNotNull);
      expect(d2.banner, contains('[GUARDRAIL_WARNING]'));
      expect(d2.banner, contains('SingleChildScrollView'));

      // Run 3: identical failure again
      final d3 = breaker.processOutput(failureLogSlightShift);
      expect(d3.level, equals(BreakerLevel.circuitBreakerTripped));
      expect(d3.consecutiveMatches, equals(3));
      expect(d3.banner, isNotNull);
      expect(d3.banner, contains('[CIRCUIT_BREAKER_TRIPPED]'));
      expect(d3.banner, contains('STRICT STOP-EDITING INSTRUCTIONS:'));
      expect(d3.shouldHalt, isTrue);

      // Run 4: test passes
      breaker.recordSuccess();
      expect(breaker.consecutiveFailures, equals(0));
      expect(breaker.currentLevel, equals(BreakerLevel.normal));
    });
  });
}
