import 'dart:convert';
import 'package:test/test.dart';
import 'package:flutter_sanity_mcp/flutter_sanity_mcp.dart';

void main() {
  group('FlutterTestStreamParser', () {
    test('1. Passing test suite with flutter startedProcess array line', () {
      final ndjson = [
        '[{"event":"test.startedProcess","params":{"processId":12345}}]',
        '{"type":"start","protocolVersion":"0.1.1","runnerVersion":"1.25.0","pid":12345,"time":0}',
        '{"type":"allSuites","count":1,"time":1}',
        '{"type":"suite","suite":{"id":0,"platform":"vm","path":"test/math_test.dart"},"time":2}',
        '{"type":"testStart","test":{"id":1,"name":"loading test/math_test.dart","suiteID":0,"groupIDs":[],"metadata":{"skip":false},"line":null,"column":null,"url":null,"hidden":true},"time":3}',
        '{"type":"testDone","testID":1,"result":"success","hidden":true,"skipped":false,"time":10}',
        '{"type":"testStart","test":{"id":2,"name":"addition works","suiteID":0,"groupIDs":[],"metadata":{"skip":false},"line":5,"column":3,"url":"file:///C:/projects/app/test/math_test.dart"},"time":12}',
        '{"type":"testDone","testID":2,"result":"success","hidden":false,"skipped":false,"time":50}',
        '{"type":"testStart","test":{"id":3,"name":"multiplication works","suiteID":0,"groupIDs":[],"metadata":{"skip":false},"line":10,"column":3,"url":"file:///C:/projects/app/test/math_test.dart"},"time":52}',
        '{"type":"testDone","testID":3,"result":"success","hidden":false,"skipped":false,"time":95}',
        '{"type":"done","success":true,"time":100}',
      ].join('\n');

      final summary = FlutterTestStreamParser.parse(ndjson);

      expect(summary.success, isTrue);
      expect(summary.passed, equals(2));
      expect(summary.failed, equals(0));
      expect(summary.errors, equals(0));
      expect(summary.skipped, equals(0));
      expect(summary.total, equals(2));
      expect(summary.durationMs, equals(100));
      expect(summary.failures, isEmpty);

      // Verify high density output
      final jsonOutput = summary.toHighDensityJson();
      final lineCount = jsonOutput.split('\n').length;
      expect(lineCount, lessThan(15));

      final decoded = jsonDecode(jsonOutput) as Map<String, dynamic>;
      expect(decoded['success'], isTrue);
      expect(decoded['passed'], equals(2));
      expect(decoded['failures'], isEmpty);
    });

    test('2. Unit test assertion failure with pruned stack trace', () {
      final ndjson = [
        '{"type":"start","protocolVersion":"0.1.1","runnerVersion":"1.25.0","pid":2345,"time":0}',
        '{"type":"suite","suite":{"id":0,"platform":"vm","path":"test/calculator_test.dart"},"time":1}',
        '{"type":"testStart","test":{"id":1,"name":"loading test/calculator_test.dart","suiteID":0,"groupIDs":[],"metadata":{"skip":false},"line":null,"column":null,"url":null,"hidden":true},"time":2}',
        '{"type":"testDone","testID":1,"result":"success","hidden":true,"skipped":false,"time":8}',
        '{"type":"testStart","test":{"id":2,"name":"calculator adds two numbers","suiteID":0,"groupIDs":[],"metadata":{"skip":false},"line":8,"column":3,"url":"file:///C:/projects/app/test/calculator_test.dart"},"time":10}',
        '{"type":"error","testID":2,"error":"Expected: <5>\\n  Actual: <4>\\n","stackTrace":"package:matcher/src/expect/expect.dart 136:31  fail\\npackage:matcher/src/expect/expect.dart 123:3   _expect\\ntest/calculator_test.dart 12:5                main.<anonymous closure>\\ndart:async/zone.dart 1400:47                  _rootRun\\n","isFailure":true,"time":20}',
        '{"type":"testDone","testID":2,"result":"failure","hidden":false,"skipped":false,"time":25}',
        '{"type":"done","success":false,"time":30}',
      ].join('\n');

      final summary = FlutterTestStreamParser.parse(ndjson);

      expect(summary.success, isFalse);
      expect(summary.passed, equals(0));
      expect(summary.failed, equals(1));
      expect(summary.total, equals(1));
      expect(summary.failures, hasLength(1));

      final failure = summary.failures.first;
      expect(failure.test, equals('calculator adds two numbers'));
      expect(failure.failureType, equals('assertion'));
      expect(failure.error, contains('Expected: <5>'));
      expect(failure.error, contains('Actual: <4>'));

      // Verify stack pruning: package:matcher and dart:async stripped, test frame kept
      expect(failure.stack, equals(['test/calculator_test.dart:12:5']));
      expect(failure.location, equals('test/calculator_test.dart:12:5'));

      // Verify high density output is < 15 lines
      final jsonOutput = summary.toHighDensityJson();
      final lineCount = jsonOutput.split('\n').length;
      expect(lineCount, lessThan(15));

      final decoded = jsonDecode(jsonOutput) as Map<String, dynamic>;
      expect(decoded['success'], isFalse);
      expect(decoded['failures'], hasLength(1));
    });

    test(
        '3. Widget test RenderFlex overflow & print banner extraction (Framework Log Trap defeated)',
        () {
      // Generate 400 lines of ASCII box tree noise that Flutter typically produces
      final asciiTreeNoise = List.generate(
        400,
        (i) =>
            ' │ ├──RenderParagraph#$i relayoutBoundary=up1 (text: "child $i")',
      ).join('\n');

      final printBanner = [
        '══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════',
        'The following assertion was thrown during layout:',
        'A RenderFlex overflowed by 42.0 pixels on the bottom.',
        '',
        'The relevant error-causing widget was:',
        '  Column Column:file:///C:/projects/app/lib/profile_screen.dart:55:12',
        '',
        'The overflowing RenderFlex has an orientation of Axis.vertical.',
        'The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and',
        'black striped pattern.',
        '',
        'constraints: BoxConstraints(0.0<=w<=800.0, 0.0<=h<=600.0)',
        'size: Size(800.0, 600.0)',
        '',
        asciiTreeNoise,
        '',
        'When the exception was thrown, this was the stack:',
        '#0      RenderFlex._layout (package:flutter/src/rendering/flex.dart:1234:5)',
        '#1      RenderObject.layout (package:flutter/src/rendering/object.dart:567:8)',
        '#2      main.<anonymous closure> (file:///C:/projects/app/test/profile_widget_test.dart:22:9)',
        '#3      testWidgets.<anonymous closure> (package:flutter_test/src/widget_tester.dart:170:29)',
        '<asynchronous suspension>',
        '════════════════════════════════════════════════════════════════════════════════════════════════════',
      ].join('\n');

      final ndjson = [
        '{"type":"start","protocolVersion":"0.1.1","runnerVersion":"1.25.0","pid":5678,"time":0}',
        '{"type":"suite","suite":{"id":0,"platform":"vm","path":"test/profile_widget_test.dart"},"time":1}',
        '{"type":"testStart","test":{"id":1,"name":"loading test/profile_widget_test.dart","suiteID":0,"groupIDs":[],"metadata":{"skip":false},"hidden":true},"time":2}',
        '{"type":"testDone","testID":1,"result":"success","hidden":true,"skipped":false,"time":5}',
        '{"type":"testStart","test":{"id":2,"name":"profile screen renders without overflow","suiteID":0,"groupIDs":[],"metadata":{"skip":false},"line":15,"column":3,"url":"file:///C:/projects/app/test/profile_widget_test.dart"},"time":10}',
        jsonEncode({
          'type': 'print',
          'testID': 2,
          'message': printBanner,
          'time': 30,
        }),
        // THE FRAMEWORK LOG TRAP: empty/generic error event emitted by Flutter!
        '{"type":"error","testID":2,"error":"Test failed with 1 error.","stackTrace":"","isFailure":false,"time":35}',
        '{"type":"testDone","testID":2,"result":"error","hidden":false,"skipped":false,"time":40}',
        '{"type":"done","success":false,"time":45}',
      ].join('\n');

      final summary = FlutterTestStreamParser.parse(ndjson);

      expect(summary.success, isFalse);
      expect(summary.errors, equals(1));
      expect(summary.failures, hasLength(1));

      final failure = summary.failures.first;
      expect(failure.test, equals('profile screen renders without overflow'));
      expect(failure.failureType, equals('overflow'));

      // The generic "Test failed with 1 error." must be replaced with squashed summary!
      expect(failure.error, isNot(equals('Test failed with 1 error.')));
      expect(failure.error,
          contains('RenderFlex overflowed by 42.0px on the bottom'));
      expect(failure.error, contains('(Axis.vertical)'));
      expect(failure.error, contains('Column (lib/profile_screen.dart:55:12)'));
      expect(failure.error,
          contains('BoxConstraints(0.0<=w<=800.0, 0.0<=h<=600.0)'));

      // Location points directly to origin
      expect(failure.location, equals('lib/profile_screen.dart:55:12'));

      // Pruned stack: package:flutter and package:flutter_test stripped, test frame retained
      expect(failure.stack, equals(['test/profile_widget_test.dart:22:9']));

      // Ultra-clean high-density JSON output (<15 lines) despite 400 lines of original ASCII trees
      final jsonOutput = summary.toHighDensityJson();
      final lineCount = jsonOutput.split('\n').length;
      expect(lineCount, lessThan(15));
    });

    test('4. pumpAndSettle timeout with Windows drive letter path parsing', () {
      final banner = [
        '══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════',
        'The following FlutterError was caught running a test:',
        'pumpAndSettle timed out',
        '',
        'When the exception was thrown, this was the stack:',
        '#0      WidgetTester.pumpAndSettle.<anonymous closure> (package:flutter_test/src/widget_tester.dart:676:13)',
        r'#1      main.<anonymous closure> (C:\projects\app\test\animation_widget_test.dart:18:20)',
        '<asynchronous suspension>',
        '════════════════════════════════════════════════════════════════════════════════════════════════════',
      ].join('\n');

      final ndjson = [
        '{"type":"start","protocolVersion":"0.1.1","runnerVersion":"1.25.0","pid":7890,"time":0}',
        '{"type":"suite","suite":{"id":0,"platform":"vm","path":"test/animation_widget_test.dart"},"time":1}',
        '{"type":"testStart","test":{"id":1,"name":"loading test/animation_widget_test.dart","suiteID":0,"groupIDs":[],"metadata":{"skip":false},"hidden":true},"time":2}',
        '{"type":"testDone","testID":1,"result":"success","hidden":true,"skipped":false,"time":5}',
        '{"type":"testStart","test":{"id":2,"name":"infinite spinner settles","suiteID":0,"groupIDs":[],"metadata":{"skip":false},"line":12,"column":3,"url":"file:///C:/projects/app/test/animation_widget_test.dart"},"time":10}',
        jsonEncode({
          'type': 'print',
          'testID': 2,
          'message': banner,
          'time': 30,
        }),
        '{"type":"error","testID":2,"error":"Test failed with 1 error.","stackTrace":"","isFailure":false,"time":35}',
        '{"type":"testDone","testID":2,"result":"error","hidden":false,"skipped":false,"time":40}',
        '{"type":"done","success":false,"time":45}',
      ].join('\n');

      final summary = FlutterTestStreamParser.parse(ndjson);

      expect(summary.success, isFalse);
      expect(summary.failures, hasLength(1));

      final failure = summary.failures.first;
      expect(failure.test, equals('infinite spinner settles'));
      expect(failure.failureType, equals('timeout'));
      expect(failure.error, equals('pumpAndSettle timed out'));

      // Windows path parsed without regex colon split error, flutter_test stripped
      expect(failure.stack, equals(['test/animation_widget_test.dart:18:20']));
      expect(failure.location, equals('test/animation_widget_test.dart:18:20'));

      // High density output line count
      final jsonOutput = summary.toHighDensityJson();
      expect(jsonOutput.split('\n').length, lessThan(15));
    });

    test('5. Compilation failure (loading <path>)', () {
      final ndjson = [
        '{"type":"start","protocolVersion":"0.1.1","runnerVersion":"1.25.0","pid":9999,"time":0}',
        '{"type":"suite","suite":{"id":0,"platform":"vm","path":"test/broken_syntax_test.dart"},"time":1}',
        '{"type":"testStart","test":{"id":1,"name":"loading test/broken_syntax_test.dart","suiteID":0,"groupIDs":[],"metadata":{"skip":false},"line":null,"column":null,"url":null,"hidden":true},"time":2}',
        '{"type":"error","testID":1,"error":"test/broken_syntax_test.dart:14:3: Error: Undefined name \'nonExistentMethod\'.\\n  nonExistentMethod();\\n  ^^^^^^^^^^^^^^^^^","stackTrace":"","isFailure":false,"time":10}',
        '{"type":"testDone","testID":1,"result":"error","hidden":true,"skipped":false,"time":15}',
        '{"type":"done","success":false,"time":20}',
      ].join('\n');

      final summary = FlutterTestStreamParser.parse(ndjson);

      expect(summary.success, isFalse);
      expect(summary.errors, equals(1));
      expect(summary.total, equals(1));
      expect(summary.failures, hasLength(1));

      final failure = summary.failures.first;
      expect(failure.failureType, equals('compilation'));
      expect(failure.location, equals('test/broken_syntax_test.dart:14:3'));
      expect(failure.error,
          contains("Error: Undefined name 'nonExistentMethod'."));
      expect(failure.stack, isEmpty);

      // High density output line count
      final jsonOutput = summary.toHighDensityJson();
      expect(jsonOutput.split('\n').length, lessThan(15));
    });

    test('6. Widget test assertion failure in framework print banner', () {
      final banner = [
        '══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════',
        'The following TestFailure was thrown running a test:',
        '  Expected: exactly one matching candidate',
        '  Actual: _TextWidgetFinder:<zero widgets with text "Submit" (ignoring offstage)>',
        '   Which: means none were found but one was expected',
        '',
        'When the exception was thrown, this was the stack:',
        '#0      fail (package:test_api/src/expect/expect.dart:136:31)',
        '#1      _expect (package:test_api/src/expect/expect.dart:123:3)',
        '#2      expect (package:test_api/src/expect/expect.dart:58:3)',
        '#3      main.<anonymous closure> (file:///C:/projects/app/test/login_widget_test.dart:32:7)',
        '<asynchronous suspension>',
        '#4      testWidgets.<anonymous closure> (package:flutter_test/src/widget_tester.dart:170:29)',
        '<asynchronous suspension>',
        '════════════════════════════════════════════════════════════════════════════════════════════════════',
      ].join('\n');

      final ndjson = [
        '{"type":"start","protocolVersion":"0.1.1","runnerVersion":"1.25.0","pid":1111,"time":0}',
        '{"type":"suite","suite":{"id":0,"platform":"vm","path":"test/login_widget_test.dart"},"time":1}',
        '{"type":"testStart","test":{"id":2,"name":"login button is rendered","suiteID":0,"groupIDs":[],"metadata":{"skip":false},"line":25,"column":3,"url":"file:///C:/projects/app/test/login_widget_test.dart"},"time":10}',
        jsonEncode({
          'type': 'print',
          'testID': 2,
          'message': banner,
          'time': 20,
        }),
        '{"type":"error","testID":2,"error":"Test failed with 1 error.","stackTrace":"","isFailure":false,"time":25}',
        '{"type":"testDone","testID":2,"result":"error","hidden":false,"skipped":false,"time":30}',
        '{"type":"done","success":false,"time":35}',
      ].join('\n');

      final summary = FlutterTestStreamParser.parse(ndjson);

      expect(summary.success, isFalse);
      expect(summary.failures, hasLength(1));

      final failure = summary.failures.first;
      expect(failure.test, equals('login button is rendered'));
      expect(failure.failureType, equals('assertion'));
      expect(
          failure.error, contains('Expected: exactly one matching candidate'));
      expect(
          failure.error,
          contains(
              'Actual: _TextWidgetFinder:<zero widgets with text "Submit"'));
      expect(failure.stack, equals(['test/login_widget_test.dart:32:7']));
      expect(failure.location, equals('test/login_widget_test.dart:32:7'));
    });

    test('7. Pruning stack traces with various Windows file paths', () {
      const rawStack = '''
#0      SomeFramework.call (package:flutter/src/widgets/framework.dart:100:12)
#1      MyService.fetch (package:my_app/services/api.dart:45:10)
#2      main.<anonymous closure> (C:\\Users\\FIRAT ISPIR\\projects\\app\\test\\unit_test.dart:50:5)
#3      testHelper (file:///C:/Users/FIRAT%20ISPIR/projects/app/test/helper.dart:15:3)
#4      Zone.run (dart:async/zone.dart:1000:20)
#5      TestCompat.run (package:test_api/src/backend/invoker.dart:200:10)
''';

      final pruned = FlutterTestStreamParser.pruneStackTrace(rawStack,
          projectName: 'my_app');

      expect(pruned, contains('package:my_app/services/api.dart:45:10'));
      expect(pruned, contains('test/unit_test.dart:50:5'));
      expect(pruned, contains('test/helper.dart:15:3'));
      // Framework and SDK frames must be stripped
      expect(pruned.any((f) => f.contains('package:flutter')), isFalse);
      expect(pruned.any((f) => f.contains('dart:async')), isFalse);
      expect(pruned.any((f) => f.contains('package:test_api')), isFalse);
    });

    test('8. Streaming feedLine parses incrementally', () {
      final parser = FlutterTestStreamParser();
      parser.feedLine('{"type":"start","time":0}');
      parser.feedLine(
          '{"type":"suite","suite":{"id":0,"path":"test/a_test.dart"}}');
      parser.feedLine(
          '{"type":"testStart","test":{"id":1,"name":"first test","suiteID":0}}');
      parser.feedLine('{"type":"testDone","testID":1,"result":"success"}');
      parser.feedLine('{"type":"done","success":true,"time":42}');

      final summary = parser.finish();
      expect(summary.success, isTrue);
      expect(summary.passed, equals(1));
      expect(summary.durationMs, equals(42));
    });
  });
}
