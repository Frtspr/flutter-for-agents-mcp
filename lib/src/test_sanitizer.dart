import 'dart:convert';

/// High-density test summary formatted for LLMs and agents.
class FlutterTestSummary {
  final bool success;
  final int passed;
  final int failed;
  final int errors;
  final int skipped;
  final int total;
  final int durationMs;
  final List<TestFailureDetail> failures;

  const FlutterTestSummary({
    required this.success,
    required this.passed,
    required this.failed,
    required this.errors,
    required this.skipped,
    required this.total,
    required this.durationMs,
    required this.failures,
  });

  Map<String, dynamic> toJson() => {
    'success': success,
    'passed': passed,
    'failed': failed,
    'errors': errors,
    'skipped': skipped,
    'total': total,
    'durationMs': durationMs,
    if (failures.isNotEmpty)
      'failures': failures.map((f) => f.toJson()).toList(),
  };

  /// Ultra-clean, high-density JSON summary (<15 lines) designed to prevent agent doom loops.
  String toHighDensityJson({int maxFailures = 5}) {
    final buffer = StringBuffer();
    buffer.writeln('{');
    buffer.writeln('  "success": $success,');
    buffer.writeln(
      '  "passed": $passed, "failed": $failed, "errors": $errors, "skipped": $skipped, "total": $total, "durationMs": $durationMs,',
    );
    if (failures.isEmpty) {
      buffer.writeln('  "failures": []');
    } else {
      buffer.writeln('  "failures": [');
      final displayList = failures.take(maxFailures).toList();
      for (var i = 0; i < displayList.length; i++) {
        final f = displayList[i];
        final isLast = i == displayList.length - 1 && failures.length <= maxFailures;
        buffer.writeln('    {');
        buffer.writeln('      "test": ${jsonEncode(f.test)},');
        if (f.location != null) {
          buffer.writeln('      "location": ${jsonEncode(f.location)},');
        }
        if (f.failureType != null) {
          buffer.writeln('      "type": ${jsonEncode(f.failureType)},');
        }
        buffer.writeln('      "error": ${jsonEncode(f.error)},');
        buffer.writeln('      "stack": ${jsonEncode(f.stack)}');
        buffer.writeln('    }${isLast ? '' : ','}');
      }
      if (failures.length > maxFailures) {
        buffer.writeln('    {"remainingFailures": ${failures.length - maxFailures}}');
      }
      buffer.writeln('  ]');
    }
    buffer.writeln('}');
    return buffer.toString().trimRight();
  }

  @override
  String toString() => toHighDensityJson();
}

/// Detail for an individual test failure with sanitized stack and error message.
class TestFailureDetail {
  final String test;
  final String? location;
  final String error;
  final List<String> stack;
  final String? failureType;

  const TestFailureDetail({
    required this.test,
    this.location,
    required this.error,
    required this.stack,
    this.failureType,
  });

  Map<String, dynamic> toJson() => {
    'test': test,
    if (location != null) 'location': location,
    if (failureType != null) 'type': failureType,
    'error': error,
    'stack': stack,
  };
}

/// Stream and batch parser for `flutter test --machine` and `dart test --reporter=json`.
class FlutterTestStreamParser {
  final String? projectName;

  final Map<int, String> _suites = {};
  final Map<int, _TestEntry> _tests = {};
  final Map<int, List<String>> _testPrints = {};
  final Map<int, List<_ErrorEntry>> _testErrors = {};
  final List<String> _unhandledCompileErrors = [];

  int _totalDurationMs = 0;
  int _passed = 0;
  int _failed = 0;
  int _errors = 0;
  int _skipped = 0;
  int _total = 0;
  bool? _suiteSuccess;

  FlutterTestStreamParser({this.projectName});

  /// Convenient helper to parse full test output string at once.
  static FlutterTestSummary parse(String output, {String? projectName}) {
    final parser = FlutterTestStreamParser(projectName: projectName);
    parser.feedOutput(output);
    return parser.finish();
  }

  /// Feeds full output string, splitting on newlines.
  void feedOutput(String output) {
    final lines = const LineSplitter().convert(output);
    for (final line in lines) {
      feedLine(line);
    }
  }

  /// Feeds a collection of lines.
  void feedLines(Iterable<String> lines) {
    for (final line in lines) {
      feedLine(line);
    }
  }

  /// Feeds a single line of NDJSON or array JSON.
  void feedLine(String rawLine) {
    final line = rawLine.trim();
    if (line.isEmpty) return;

    // Support [{"event":"test.startedProcess",...}] array line emitted by flutter test
    if (line.startsWith('[') && line.endsWith(']')) {
      try {
        final decoded = jsonDecode(line);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              _processEvent(item);
            }
          }
          return;
        }
      } catch (_) {
        // Fall through if not valid JSON
      }
    }

    // Support standard NDJSON line objects
    if (line.startsWith('{') && line.endsWith('}')) {
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic>) {
          _processEvent(decoded);
          return;
        }
      } catch (_) {
        // Fall through if not valid JSON
      }
    }

    // Check for raw compiler errors that may appear outside JSON events
    _checkRawCompilerOutput(line);
  }

  void _processEvent(Map<String, dynamic> event) {
    final type = event['type'] as String? ?? event['event'] as String?;
    if (type == null) return;

    switch (type) {
      case 'suite':
        final suite = event['suite'];
        if (suite is Map<String, dynamic>) {
          final id = suite['id'] as int?;
          final path = suite['path'] as String?;
          if (id != null && path != null) {
            _suites[id] = path;
          }
        }
        break;

      case 'testStart':
        final test = event['test'];
        if (test is Map<String, dynamic>) {
          final id = test['id'] as int?;
          final name = test['name'] as String? ?? 'unnamed test';
          final suiteID = test['suiteID'] as int? ?? 0;
          final url = test['url'] as String?;
          final line = test['line'] as int?;
          final column = test['column'] as int?;
          final metadata = test['metadata'] as Map<String, dynamic>?;
          final skip = metadata?['skip'] as bool? ?? false;
          final hidden = (test['hidden'] as bool?) ?? false;

          if (id != null) {
            _tests[id] = _TestEntry(
              id: id,
              name: name,
              suiteID: suiteID,
              url: url,
              line: line,
              column: column,
              hidden: hidden,
            );
            if (skip && !hidden) {
              _skipped++;
            }
          }
        }
        break;

      case 'print':
        final testID = event['testID'] as int?;
        final message = event['message'] as String? ?? '';
        if (testID != null) {
          _testPrints.putIfAbsent(testID, () => []).add(message);
        }
        break;

      case 'error':
        final testID = event['testID'] as int?;
        final error = event['error'] as String? ?? '';
        final stackTrace = event['stackTrace'] as String? ?? '';
        final isFailure = event['isFailure'] as bool? ?? false;
        if (testID != null) {
          _testErrors.putIfAbsent(testID, () => []).add(
            _ErrorEntry(
              error: error,
              stackTrace: stackTrace,
              isFailure: isFailure,
            ),
          );
        }
        break;

      case 'testDone':
        final testID = event['testID'] as int?;
        final result = event['result'] as String? ?? 'success';
        final hidden = event['hidden'] as bool? ?? false;
        final skipped = event['skipped'] as bool? ?? false;
        final time = event['time'] as int?;
        if (time != null && time > _totalDurationMs) {
          _totalDurationMs = time;
        }

        if (testID != null && _tests.containsKey(testID)) {
          final test = _tests[testID]!;
          test.result = result;
          test.isCompleted = true;

          if (hidden) {
            // Hidden tests (e.g. "loading <path>") only count towards totals if they fail (compilation error)
            if (result == 'failure') {
              _failed++;
              _total++;
            } else if (result == 'error') {
              _errors++;
              _total++;
            }
          } else {
            _total++;
            if (skipped) {
              // already counted in skip or metadata
            } else if (result == 'success') {
              _passed++;
            } else if (result == 'failure') {
              _failed++;
            } else if (result == 'error') {
              _errors++;
            }
          }
        }
        break;

      case 'done':
        final success = event['success'] as bool?;
        if (success != null) {
          _suiteSuccess = success;
        }
        final time = event['time'] as int?;
        if (time != null && time > _totalDurationMs) {
          _totalDurationMs = time;
        }
        break;
    }
  }

  void _checkRawCompilerOutput(String line) {
    final match = RegExp(
      r'^((?:[A-Za-z]:[\\/])?[^:\r\n]+):(\d+):(\d+):\s*Error:\s*(.*)$',
    ).firstMatch(line);
    if (match != null) {
      _unhandledCompileErrors.add(line);
    }
  }

  /// Finalizes parsing and produces an ultra-clean [FlutterTestSummary].
  FlutterTestSummary finish() {
    final failures = <TestFailureDetail>[];

    for (final test in _tests.values) {
      final hasErrors = _testErrors.containsKey(test.id);
      final isFailed =
          test.result == 'failure' ||
          test.result == 'error' ||
          (!test.isCompleted && hasErrors);

      // Hidden tests (like "loading <path>") that succeeded are internal runner plumbing
      if (test.hidden && test.result == 'success') {
        continue;
      }

      if (isFailed || hasErrors) {
        final detail = _sanitizeFailure(test);
        if (detail != null) {
          failures.add(detail);
        }
      }
    }

    // Include any unhandled compilation errors not attached to a test
    for (final errLine in _unhandledCompileErrors) {
      failures.add(
        TestFailureDetail(
          test: 'compilation',
          location: _extractLocationFromCompilerLine(errLine),
          error: errLine,
          stack: const [],
          failureType: 'compilation',
        ),
      );
    }

    final computedSuccess =
        _suiteSuccess ??
        (failures.isEmpty && _failed == 0 && _errors == 0);

    return FlutterTestSummary(
      success: computedSuccess,
      passed: _passed,
      failed: _failed,
      errors: _errors,
      skipped: _skipped,
      total: _total,
      durationMs: _totalDurationMs,
      failures: failures,
    );
  }

  TestFailureDetail? _sanitizeFailure(_TestEntry test) {
    final prints = _testPrints[test.id] ?? const [];
    final errors = _testErrors[test.id] ?? const [];

    // 1. Check for the "Framework Log Trap": widget test failures have empty `error` events,
    // but the real assertion diffs, RenderFlex overflows, or timeouts are in `print` banners.
    final frameworkBanner = _findFrameworkBanner(prints);
    if (frameworkBanner != null) {
      return _extractFromFrameworkBanner(test, frameworkBanner);
    }

    // 2. Compilation failures in `loading <path>` tests
    if (test.name.startsWith('loading ') || test.hidden) {
      final rawError = errors.isNotEmpty ? errors.first.error : '';
      final location = _extractLocationFromCompilerError(rawError) ?? _formatTestLocation(test);
      return TestFailureDetail(
        test: test.name,
        location: location,
        error: rawError.isNotEmpty ? rawError.trim() : 'Compilation error',
        stack: const [],
        failureType: 'compilation',
      );
    }

    // 3. Standard unit test assertion failure or runtime exception
    if (errors.isNotEmpty) {
      final err = errors.first;
      var cleanError = err.error.trim();

      // If the error message is the generic framework message, check prints for details
      if (cleanError.isEmpty || cleanError == 'Test failed with 1 error.') {
        final altError = _extractErrorFromPrints(prints);
        if (altError != null) {
          cleanError = altError;
        }
      }

      var prunedStack = pruneStackTrace(err.stackTrace, projectName: projectName);
      if (prunedStack.isEmpty && prints.isNotEmpty) {
        // Fallback: stack might be in prints
        prunedStack = pruneStackTrace(prints.join('\n'), projectName: projectName);
      }

      final location =
          prunedStack.isNotEmpty ? prunedStack.first : _formatTestLocation(test);

      final failureType = cleanError.contains('Expected:') ? 'assertion' : 'error';

      return TestFailureDetail(
        test: test.name,
        location: location,
        error: cleanError,
        stack: prunedStack,
        failureType: failureType,
      );
    }

    // 4. Test finished with error/failure status but no explicit error event
    final altError = _extractErrorFromPrints(prints) ?? 'Test failed without explicit error';
    final prunedStack = pruneStackTrace(prints.join('\n'), projectName: projectName);
    return TestFailureDetail(
      test: test.name,
      location: prunedStack.isNotEmpty ? prunedStack.first : _formatTestLocation(test),
      error: altError,
      stack: prunedStack,
      failureType: 'error',
    );
  }

  String? _findFrameworkBanner(List<String> prints) {
    for (final msg in prints) {
      if (msg.contains('══╡ EXCEPTION CAUGHT BY')) {
        return msg;
      }
    }
    return null;
  }

  TestFailureDetail _extractFromFrameworkBanner(_TestEntry test, String bannerText) {
    // A: RenderObject / RenderFlex tree squashing
    if (bannerText.contains('overflowed by') ||
        bannerText.contains('EXCEPTION CAUGHT BY RENDERING LIBRARY') ||
        bannerText.contains('during layout:')) {
      return _squashRenderObjectTree(test, bannerText);
    }

    // B: pumpAndSettle timeout
    if (bannerText.contains('pumpAndSettle timed out')) {
      final prunedStack = _extractStackFromBanner(bannerText);
      final location =
          prunedStack.isNotEmpty ? prunedStack.first : _formatTestLocation(test);
      return TestFailureDetail(
        test: test.name,
        location: location,
        error: 'pumpAndSettle timed out',
        stack: prunedStack,
        failureType: 'timeout',
      );
    }

    // C: Widget test assertion failure (Expected / Actual in framework log)
    final diff = _extractAssertionDiff(bannerText);
    final prunedStack = _extractStackFromBanner(bannerText);
    final location =
        prunedStack.isNotEmpty ? prunedStack.first : _formatTestLocation(test);

    return TestFailureDetail(
      test: test.name,
      location: location,
      error: diff ?? _extractExceptionHeadline(bannerText) ?? 'Assertion failure',
      stack: prunedStack,
      failureType: 'assertion',
    );
  }

  /// Squashes 400 lines of RenderObject diagnostic trees down to concise constraint summaries
  /// containing component, overflow pixels, orientation, and origin file/line.
  TestFailureDetail _squashRenderObjectTree(_TestEntry test, String bannerText) {
    // Check for unbounded viewport / flex constraints error
    final unboundedMatch = RegExp(
      r'((?:Vertical|Horizontal)\s+viewport was given unbounded\s+(?:height|width)|RenderFlex children have non-zero flex but incoming\s+(?:height|width)\s+constraints are unbounded)',
      caseSensitive: false,
    ).firstMatch(bannerText);

    // 1. Overflow pixels and edge
    final overflowMatch = RegExp(
      r'A\s+(Render\w+)\s+overflowed\s+by\s+([\d\.]+)\s+pixels?\s+(?:on\s+)?(the\s+\w+|\w+)\.?',
      caseSensitive: false,
    ).firstMatch(bannerText);

    final componentType = overflowMatch?.group(1) ?? 'RenderFlex';
    final pixels = overflowMatch?.group(2) ?? '';
    final rawEdge = overflowMatch?.group(3) ?? '';
    final edge = rawEdge.startsWith('the ') ? rawEdge : 'the $rawEdge';

    // 2. Widget component and origin file:line
    // Flutter prints:
    // The relevant error-causing widget was:
    //   Column Column:file:///C:/projects/app/lib/profile_screen.dart:55:12
    final widgetMatch = RegExp(
      r'The relevant error-causing widget was:\s*([A-Za-z0-9_]+)?(?:\s+[A-Za-z0-9_]+:|\s+)?([^\s\n\r]+)',
      caseSensitive: false,
    ).firstMatch(bannerText);

    var widgetName = widgetMatch?.group(1);
    var widgetOrigin = widgetMatch?.group(2);

    if (widgetOrigin != null) {
      widgetOrigin = widgetOrigin.replaceFirst(RegExp(r'^[A-Za-z0-9_]+:'), '');
      widgetOrigin = _normalizePath(widgetOrigin);
    }

    // 3. Orientation
    final orientationMatch = RegExp(
      r'orientation of\s+(Axis\.\w+|\w+)',
      caseSensitive: false,
    ).firstMatch(bannerText);
    final directionMatch = RegExp(
      r'direction:\s*(\w+)',
      caseSensitive: false,
    ).firstMatch(bannerText);
    final orientation =
        orientationMatch?.group(1) ?? directionMatch?.group(1) ?? '';

    // 4. Constraints
    final constraintsMatch = RegExp(
      r'constraints:\s*(BoxConstraints\([^)]+\))',
    ).firstMatch(bannerText);
    final constraints = constraintsMatch?.group(1);

    // 5. Build concise summary
    final parts = <String>[];
    final targetWidget = widgetName ?? componentType;
    if (overflowMatch != null) {
      if (pixels.isNotEmpty) {
        parts.add('$componentType overflowed by ${pixels}px on $edge');
      } else {
        parts.add('$componentType overflowed on $edge');
      }
    } else if (unboundedMatch != null) {
      parts.add(unboundedMatch.group(1)!);
    } else {
      parts.add('$componentType layout error');
    }

    if (orientation.isNotEmpty) {
      parts.add('($orientation)');
    }

    if (widgetOrigin != null) {
      parts.add('at $targetWidget ($widgetOrigin)');
    } else if (widgetName != null) {
      parts.add('at $widgetName');
    }

    var summary = parts.join(' ');
    if (constraints != null) {
      summary += '. Constraints: $constraints';
    }

    final prunedStack = _extractStackFromBanner(bannerText);
    final location =
        widgetOrigin ??
        (prunedStack.isNotEmpty ? prunedStack.first : _formatTestLocation(test));

    final failureType = unboundedMatch != null ? 'unbounded' : 'overflow';

    return TestFailureDetail(
      test: test.name,
      location: location,
      error: summary,
      stack: prunedStack,
      failureType: failureType,
    );
  }

  List<String> _extractStackFromBanner(String bannerText) {
    final stackSplit = bannerText.split('When the exception was thrown, this was the stack:');
    if (stackSplit.length > 1) {
      final rawStack = stackSplit[1].split(RegExp(r'═{10,}'))[0];
      return pruneStackTrace(rawStack, projectName: projectName);
    }
    return pruneStackTrace(bannerText, projectName: projectName);
  }

  String? _extractAssertionDiff(String text) {
    final expectedMatch = RegExp(r'Expected:\s*([^\n\r]+)').firstMatch(text);
    final actualMatch = RegExp(r'Actual:\s*([^\n\r]+)').firstMatch(text);
    final whichMatch = RegExp(r'Which:\s*([^\n\r]+)').firstMatch(text);

    if (expectedMatch != null && actualMatch != null) {
      final buffer = StringBuffer();
      buffer.write('Expected: ${expectedMatch.group(1)?.trim()}');
      buffer.write('\n  Actual: ${actualMatch.group(1)?.trim()}');
      if (whichMatch != null) {
        buffer.write('\n   Which: ${whichMatch.group(1)?.trim()}');
      }
      return buffer.toString();
    }
    return null;
  }

  String? _extractExceptionHeadline(String text) {
    final headlineMatch = RegExp(
      r'The following (?:TestFailure|assertion|FlutterError|Exception) was (?:thrown|caught)[^\n\r]*:\s*([^\n\r]+)',
      caseSensitive: false,
    ).firstMatch(text);
    return headlineMatch?.group(1)?.trim();
  }

  String? _extractErrorFromPrints(List<String> prints) {
    for (final p in prints) {
      if (p.contains('Expected:') && p.contains('Actual:')) {
        return _extractAssertionDiff(p);
      }
      if (p.contains('Error:') || p.contains('Exception:')) {
        return p.trim();
      }
    }
    return null;
  }

  String? _extractLocationFromCompilerError(String text) {
    final match = RegExp(
      r'((?:[A-Za-z]:[\\/])?[^:\r\n]+):(\d+)(?::(\d+))?',
    ).firstMatch(text);
    if (match != null) {
      final raw = match.group(0);
      if (raw != null) return _normalizePath(raw);
    }
    return null;
  }

  String? _extractLocationFromCompilerLine(String line) {
    final match = RegExp(
      r'^((?:[A-Za-z]:[\\/])?[^:\r\n]+):(\d+):(\d+)',
    ).firstMatch(line);
    if (match != null) {
      final raw = match.group(0);
      if (raw != null) return _normalizePath(raw);
    }
    return null;
  }

  String? _formatTestLocation(_TestEntry test) {
    if (test.url != null) {
      final clean = _normalizePath(test.url!);
      return test.line != null ? '$clean:${test.line}' : clean;
    }
    if (_suites.containsKey(test.suiteID)) {
      final clean = _normalizePath(_suites[test.suiteID]!);
      return test.line != null ? '$clean:${test.line}' : clean;
    }
    return null;
  }

  /// Prunes stack traces by stripping framework, sdk, matcher, test_api, and pub-cache frames.
  /// Retains only project frames (`lib/`, `test/`, `integration_test/`, `package:<projectName>/`).
  /// Correctly handles Windows file paths with drive letters without regex colon split errors.
  static List<String> pruneStackTrace(String rawStack, {String? projectName}) {
    final lines = rawStack.split('\n');
    final result = <String>[];

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('════') || line.startsWith('◢◤')) continue;
      if (line == '<asynchronous suspension>') continue;

      final frame = _parseStackFrame(line);
      if (frame == null) continue;

      if (_shouldStripFrame(frame.rawPath) || _shouldStripFrame(frame.cleanPath)) continue;

      if (_isProjectFrame(frame.cleanPath, frame.rawPath, projectName: projectName)) {
        final clean = frame.toCleanString();
        if (!result.contains(clean)) {
          result.add(clean);
        }
      }
    }

    // If all frames were stripped, retain top non-framework frame as fallback
    if (result.isEmpty) {
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('═') || line == '<asynchronous suspension>') continue;
        final frame = _parseStackFrame(line);
        if (frame != null &&
            !_shouldStripFrame(frame.rawPath) &&
            !_shouldStripFrame(frame.cleanPath)) {
          final clean = frame.toCleanString();
          result.add(clean);
          if (result.length >= 2) break;
        }
      }
    }

    return result;
  }

  static _StackFrame? _parseStackFrame(String line) {
    // Format 1: #0   Member (location:line:col)
    final parenMatch = RegExp(r'^\s*#\d+\s+(.+?)\s+\((.+?)\)\s*$').firstMatch(line);
    if (parenMatch != null) {
      final member = parenMatch.group(1);
      final loc = parenMatch.group(2)!;
      return _parseLocationString(loc, member: member);
    }

    // Format 2: Dart test reporter format: location line:col member
    // e.g. test/calc_test.dart 12:5 main.<closure>
    // or C:\project\test\calc_test.dart 12:5 main
    final reporterMatch = RegExp(r'^\s*(.+?)\s+(\d+):(\d+)\s+(.*?)\s*$').firstMatch(line);
    if (reporterMatch != null) {
      final rawPath = reporterMatch.group(1)!;
      final lineNum = int.tryParse(reporterMatch.group(2)!);
      final colNum = int.tryParse(reporterMatch.group(3)!);
      final member = reporterMatch.group(4);
      return _StackFrame(
        member: member,
        rawPath: rawPath,
        cleanPath: _normalizePath(rawPath),
        line: lineNum,
        column: colNum,
      );
    }

    // Format 3: Direct location string: location:line:col
    // Uses drive letter aware prefix to prevent regex colon split error on Windows!
    final directMatch = RegExp(
      r'^((?:[A-Za-z]:[\\/])?[^:\r\n]+):(\d+)(?::(\d+))?(?:\s+(.*))?$',
    ).firstMatch(line);
    if (directMatch != null) {
      final rawPath = directMatch.group(1)!;
      final lineNum = int.tryParse(directMatch.group(2)!);
      final colNum = directMatch.group(3) != null ? int.tryParse(directMatch.group(3)!) : null;
      final member = directMatch.group(4);
      return _StackFrame(
        member: member,
        rawPath: rawPath,
        cleanPath: _normalizePath(rawPath),
        line: lineNum,
        column: colNum,
      );
    }

    return null;
  }

  static _StackFrame? _parseLocationString(String loc, {String? member}) {
    // Suffix match for :line:col anchored at end prevents splitting Windows C:\ drive letter!
    final match = RegExp(r':(\d+)(?::(\d+))?$').firstMatch(loc);
    if (match != null) {
      final rawPath = loc.substring(0, match.start);
      final line = int.tryParse(match.group(1)!);
      final col = match.group(2) != null ? int.tryParse(match.group(2)!) : null;
      return _StackFrame(
        member: member,
        rawPath: rawPath,
        cleanPath: _normalizePath(rawPath),
        line: line,
        column: col,
      );
    }

    return _StackFrame(
      member: member,
      rawPath: loc,
      cleanPath: _normalizePath(loc),
    );
  }

  static bool _shouldStripFrame(String path) {
    final p = path.replaceAll(r'\', '/').toLowerCase();
    if (p.startsWith('package:flutter/') ||
        p.startsWith('package:flutter_test/') ||
        p.startsWith('package:flutter_driver/') ||
        p.startsWith('package:flutter_goldens/') ||
        p.startsWith('package:flutter_localizations/') ||
        p.startsWith('dart:') ||
        p.startsWith('package:matcher/') ||
        p.startsWith('package:test/') ||
        p.startsWith('package:test_api/') ||
        p.startsWith('package:test_core/') ||
        p.startsWith('package:stack_trace/') ||
        p.startsWith('package:stream_channel/') ||
        p.contains('/.pub-cache/') ||
        p.contains('/pub-cache/') ||
        p.contains('hosted/pub.dev') ||
        p.contains('hosted/pub.dartlang.org')) {
      return true;
    }
    return false;
  }

  static bool _isProjectFrame(String cleanPath, String rawPath, {String? projectName}) {
    final c = cleanPath.replaceAll(r'\', '/');
    final r = rawPath.replaceAll(r'\', '/');
    if (_shouldStripFrame(c) || _shouldStripFrame(r)) return false;

    if (c.startsWith('test/') ||
        c.startsWith('lib/') ||
        c.startsWith('integration_test/') ||
        r.contains('/test/') ||
        r.contains('/lib/') ||
        r.contains('/integration_test/')) {
      return true;
    }

    if (projectName != null &&
        (c.startsWith('package:$projectName/') || r.startsWith('package:$projectName/'))) {
      return true;
    }

    // Keep non-stripped packages (could be local path dependencies)
    if (c.startsWith('package:') && !_shouldStripFrame(c)) {
      return true;
    }

    return false;
  }

  static String _normalizePath(String path) {
    var p = path.trim();
    if (p.startsWith('file://')) {
      try {
        final uri = Uri.parse(p);
        p = uri.toFilePath();
      } catch (_) {
        p = p.replaceFirst(RegExp(r'^file:///?'), '');
        p = Uri.decodeComponent(p);
      }
    }

    p = p.replaceAll(r'\', '/');

    for (final prefix in ['test/', 'lib/', 'integration_test/']) {
      final idx = p.indexOf(prefix);
      if (idx != -1) {
        return p.substring(idx);
      }
    }

    return p;
  }
}

class _StackFrame {
  final String? member;
  final String rawPath;
  final String cleanPath;
  final int? line;
  final int? column;

  _StackFrame({
    this.member,
    required this.rawPath,
    required this.cleanPath,
    this.line,
    this.column,
  });

  String toCleanString() {
    final buffer = StringBuffer(cleanPath);
    if (line != null) {
      buffer.write(':$line');
      if (column != null) {
        buffer.write(':$column');
      }
    }
    return buffer.toString();
  }
}

class _TestEntry {
  final int id;
  final String name;
  final int suiteID;
  final String? url;
  final int? line;
  final int? column;
  final bool hidden;
  String? result;
  bool isCompleted = false;

  _TestEntry({
    required this.id,
    required this.name,
    required this.suiteID,
    this.url,
    this.line,
    this.column,
    this.hidden = false,
  });
}

class _ErrorEntry {
  final String error;
  final String stackTrace;
  final bool isFailure;

  _ErrorEntry({
    required this.error,
    required this.stackTrace,
    this.isFailure = false,
  });
}
