// benchmark/run_benchmark.dart
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter_sanity_mcp/flutter_sanity_mcp.dart';

/// Accurate token estimation helper based on cl100k/Claude tokenization characteristics.
class TokenEstimator {
  static const double charsPerToken = 3.8;

  static int estimate(String text) {
    if (text.isEmpty) return 0;
    return (text.length / charsPerToken).ceil();
  }
}

/// Raw empirical metrics for a text payload.
class PayloadMetrics {
  final int characters;
  final int lines;
  final int tokens;

  PayloadMetrics({
    required this.characters,
    required this.lines,
    required this.tokens,
  });

  factory PayloadMetrics.fromText(String text) {
    var lineCount = const LineSplitter().convert(text).length;
    // Count embedded escaped newlines in NDJSON payloads to reflect true visual line volume
    final escapedNewlines = RegExp(r'\\n').allMatches(text).length;
    if (escapedNewlines > lineCount) {
      lineCount += escapedNewlines;
    }
    return PayloadMetrics(
      characters: text.length,
      lines: lineCount == 0 && text.isNotEmpty ? 1 : lineCount,
      tokens: TokenEstimator.estimate(text),
    );
  }

  Map<String, dynamic> toJson() => {
    'characters': characters,
    'lines': lines,
    'tokens': tokens,
  };
}

/// Reduction metrics comparing raw vs sanitized outputs.
class ReductionMetrics {
  final double charReductionPct;
  final double lineReductionPct;
  final double tokenReductionPct;
  final int tokensSaved;

  ReductionMetrics({
    required this.charReductionPct,
    required this.lineReductionPct,
    required this.tokenReductionPct,
    required this.tokensSaved,
  });

  factory ReductionMetrics.compute(PayloadMetrics raw, PayloadMetrics sanitized) {
    double calcPct(int before, int after) {
      if (before == 0) return 0.0;
      return ((before - after) / before) * 100.0;
    }

    return ReductionMetrics(
      charReductionPct: calcPct(raw.characters, sanitized.characters),
      lineReductionPct: calcPct(raw.lines, sanitized.lines),
      tokenReductionPct: calcPct(raw.tokens, sanitized.tokens),
      tokensSaved: raw.tokens - sanitized.tokens,
    );
  }

  Map<String, dynamic> toJson() => {
    'charReductionPct': double.parse(charReductionPct.toStringAsFixed(2)),
    'lineReductionPct': double.parse(lineReductionPct.toStringAsFixed(2)),
    'tokenReductionPct': double.parse(tokenReductionPct.toStringAsFixed(2)),
    'tokensSaved': tokensSaved,
  };
}

/// Result of an individual benchmark trial.
class BenchmarkTrialResult {
  final String scenarioName;
  final String category;
  final PayloadMetrics raw;
  final PayloadMetrics sanitized;
  final ReductionMetrics reduction;
  final int processingTimeMicroseconds;
  final String? guardrailTriggered;
  final int consecutiveFailures;

  BenchmarkTrialResult({
    required this.scenarioName,
    required this.category,
    required this.raw,
    required this.sanitized,
    required this.reduction,
    required this.processingTimeMicroseconds,
    this.guardrailTriggered,
    this.consecutiveFailures = 0,
  });

  double get processingTimeMs => processingTimeMicroseconds / 1000.0;

  Map<String, dynamic> toJson() => {
    'scenarioName': scenarioName,
    'category': category,
    'raw': raw.toJson(),
    'sanitized': sanitized.toJson(),
    'reduction': reduction.toJson(),
    'processingTimeMicroseconds': processingTimeMicroseconds,
    'processingTimeMs': double.parse(processingTimeMs.toStringAsFixed(3)),
    'guardrailTriggered': guardrailTriggered,
    'consecutiveFailures': consecutiveFailures,
  };
}

/// Synthetic fixtures producing exact realistic Flutter CLI emissions.
class SyntheticFixtures {
  /// 1. 400 lines of RenderFlex diagnostic box trees produced by Flutter
  static String get renderFlexOverflowNdjson {
    final asciiNoise = List.generate(
      380,
      (i) => ' │ ├──RenderParagraph#$i relayoutBoundary=up1 (text: "child $i")',
    ).join('\\n');

    final banner = [
      '══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════',
      'The following assertion was thrown during layout:',
      'A RenderFlex overflowed by 42.0 pixels on the bottom.',
      '',
      'The relevant error-causing widget was:',
      '  Column Column:file:///C:/projects/app/lib/profile_screen.dart:55:12',
      '',
      'The overflowing RenderFlex has an orientation of Axis.vertical.',
      'constraints: BoxConstraints(0.0<=w<=800.0, 0.0<=h<=600.0)',
      'size: Size(800.0, 600.0)',
      asciiNoise,
      'When the exception was thrown, this was the stack:',
      '#0      RenderFlex._layout (package:flutter/src/rendering/flex.dart:1234:5)',
      '#1      RenderObject.layout (package:flutter/src/rendering/object.dart:567:8)',
      '#2      main.<anonymous closure> (file:///C:/projects/app/test/profile_test.dart:22:9)',
      '════════════════════════════════════════════════════════════════════════════════════════════════════',
    ].join('\\n');

    return [
      '{"type":"start","protocolVersion":"0.1.1","runnerVersion":"1.25.0","pid":5678,"time":0}',
      '{"type":"suite","suite":{"id":0,"platform":"vm","path":"test/profile_test.dart"},"time":1}',
      '{"type":"testStart","test":{"id":1,"name":"ProfileScreen layout test","suiteID":0,"groupIDs":[],"metadata":{"skip":false},"line":10,"column":3,"url":"file:///C:/projects/app/test/profile_test.dart"},"time":5}',
      '{"type":"print","testID":1,"message":"$banner","time":20}',
      '{"type":"error","testID":1,"error":"Test failed with 1 error.","stackTrace":"","isFailure":false,"time":25}',
      '{"type":"testDone","testID":1,"result":"error","hidden":false,"skipped":false,"time":30}',
      '{"type":"done","success":false,"time":35}',
    ].join('\n');
  }

  /// 2. Unbounded viewport constraints (ListView in Column)
  static String get unboundedConstraintsNdjson {
    final asciiNoise = List.generate(
      360,
      (i) => ' │ ├──RenderIndexedSemantics#$i relayoutBoundary=up1 (index: $i)',
    ).join('\\n');

    final banner = [
      '══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════',
      'The following assertion was thrown during performResize():',
      'Vertical viewport was given unbounded height.',
      'Viewports expand in the scrolling direction to fill their container. In this case, a vertical',
      'viewport was given an unlimited amount of vertical space in which for its children to',
      'determine their own size.',
      '',
      'The relevant error-causing widget was:',
      '  ListView ListView:file:///C:/projects/app/lib/feed_screen.dart:34:10',
      '',
      'constraints: BoxConstraints(0.0<=w<=800.0, 0.0<=h<=Infinity)',
      asciiNoise,
      'When the exception was thrown, this was the stack:',
      '#0      RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1340:12)',
      '#1      RenderObject.layout (package:flutter/src/rendering/object.dart:567:8)',
      '#2      main.<anonymous closure> (file:///C:/projects/app/test/feed_widget_test.dart:19:5)',
      '════════════════════════════════════════════════════════════════════════════════════════════════════',
    ].join('\\n');

    return [
      '{"type":"start","protocolVersion":"0.1.1","runnerVersion":"1.25.0","pid":5679,"time":0}',
      '{"type":"suite","suite":{"id":0,"platform":"vm","path":"test/feed_widget_test.dart"},"time":1}',
      '{"type":"testStart","test":{"id":1,"name":"FeedScreen renders unbounded ListView inside Column","suiteID":0,"groupIDs":[],"metadata":{"skip":false},"line":12,"column":3,"url":"file:///C:/projects/app/test/feed_widget_test.dart"},"time":5}',
      '{"type":"print","testID":1,"message":"$banner","time":20}',
      '{"type":"error","testID":1,"error":"Test failed with 1 error.","stackTrace":"","isFailure":false,"time":25}',
      '{"type":"testDone","testID":1,"result":"error","hidden":false,"skipped":false,"time":30}',
      '{"type":"done","success":false,"time":35}',
    ].join('\n');
  }

  /// 3. Unit test assertion failure with framework stack dump
  static String get unitTestAssertionNdjson {
    final frameworkStack = List.generate(
      60,
      (i) =>
          'package:matcher/src/expect/expect.dart ${120 + i}:10  _internalMatcherHook$i\\n'
          'package:test_api/src/backend/invoker.dart ${300 + i}:15  Invoker._runCatching$i\\n'
          'dart:async/zone.dart ${1000 + i}:25  _CustomZone.runUnary$i',
    ).join('\\n');

    final fullStack =
        'package:matcher/src/expect/expect.dart 136:31  fail\\n'
        'package:matcher/src/expect/expect.dart 123:3   _expect\\n'
        '$frameworkStack\\n'
        'test/calculator_test.dart 12:5                main.<anonymous closure>\\n'
        'dart:async/zone.dart 1400:47                  _rootRun';

    return [
      '{"type":"start","protocolVersion":"0.1.1","runnerVersion":"1.25.0","pid":2345,"time":0}',
      '{"type":"suite","suite":{"id":0,"platform":"vm","path":"test/calculator_test.dart"},"time":1}',
      '{"type":"testStart","test":{"id":1,"name":"loading test/calculator_test.dart","suiteID":0,"groupIDs":[],"metadata":{"skip":false},"line":null,"column":null,"url":null,"hidden":true},"time":2}',
      '{"type":"testDone","testID":1,"result":"success","hidden":true,"skipped":false,"time":8}',
      '{"type":"testStart","test":{"id":2,"name":"calculator adds two numbers","suiteID":0,"groupIDs":[],"metadata":{"skip":false},"line":8,"column":3,"url":"file:///C:/projects/app/test/calculator_test.dart"},"time":10}',
      '{"type":"error","testID":2,"error":"Expected: <5>\\n  Actual: <4>\\n   Which: was \'4\' instead of \'5\'","stackTrace":"$fullStack","isFailure":true,"time":20}',
      '{"type":"testDone","testID":2,"result":"failure","hidden":false,"skipped":false,"time":25}',
      '{"type":"done","success":false,"time":30}',
    ].join('\n');
  }

  /// 4. pumpAndSettle timeout with infinite animation framework stack dump
  static String get pumpAndSettleTimeoutNdjson {
    final frameworkStack = List.generate(
      60,
      (i) =>
          '#${i + 1}      WidgetTester.pump (package:flutter_test/src/widget_tester.dart:${200 + i}:10)\\n'
          '#${i + 2}      SchedulerBinding.handleBeginFrame (package:flutter/src/scheduler/binding.dart:${500 + i}:8)\\n'
          '#${i + 3}      _CustomZone.run (dart:async/zone.dart:${1100 + i}:19)',
    ).join('\\n');

    final banner = [
      '══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════',
      'The following FlutterError was caught running a test:',
      'pumpAndSettle timed out',
      '',
      'When the exception was thrown, this was the stack:',
      '#0      WidgetTester.pumpAndSettle.<anonymous closure> (package:flutter_test/src/widget_tester.dart:676:13)',
      frameworkStack,
      r'#185    main.<anonymous closure> (C:\projects\app\test\animation_widget_test.dart:18:20)',
      '<asynchronous suspension>',
      '════════════════════════════════════════════════════════════════════════════════════════════════════',
    ].join('\\n');

    return [
      '{"type":"start","protocolVersion":"0.1.1","runnerVersion":"1.25.0","pid":7890,"time":0}',
      '{"type":"suite","suite":{"id":0,"platform":"vm","path":"test/animation_widget_test.dart"},"time":1}',
      '{"type":"testStart","test":{"id":1,"name":"loading test/animation_widget_test.dart","suiteID":0,"groupIDs":[],"metadata":{"skip":false},"hidden":true},"time":2}',
      '{"type":"testDone","testID":1,"result":"success","hidden":true,"skipped":false,"time":5}',
      '{"type":"testStart","test":{"id":2,"name":"infinite spinner settles","suiteID":0,"groupIDs":[],"metadata":{"skip":false},"line":12,"column":3,"url":"file:///C:/projects/app/test/animation_widget_test.dart"},"time":10}',
      '{"type":"print","testID":2,"message":"$banner","time":30}',
      '{"type":"error","testID":2,"error":"Test failed with 1 error.","stackTrace":"","isFailure":false,"time":35}',
      '{"type":"testDone","testID":2,"result":"error","hidden":false,"skipped":false,"time":40}',
      '{"type":"done","success":false,"time":45}',
    ].join('\n');
  }

  /// 5. 50 pipe-delimited analyzer errors/warnings (flutter analyze --machine)
  static String get analyzeMachineFiftyIssues {
    final buffer = StringBuffer();
    buffer.writeln('Analyzing enterprise_flutter_application...');
    for (int i = 1; i <= 50; i++) {
      final severity = i <= 2 ? 'ERROR' : (i <= 10 ? 'WARNING' : 'INFO');
      final errType = i <= 2 ? 'COMPILE_TIME_ERROR_TYPE_CHECK' : 'STATIC_TYPE_WARNING_ANALYSIS';
      buffer.writeln(
        '$severity|$errType|undefined_identifier_or_unused_import|packages/features/profile/lib/src/presentation/controllers/profile_view_controller_$i.dart|$i|5|10|The variable "temp$i" isn\'t used.',
      );
    }
    buffer.writeln('50 issues found. (ran in 2.4s)');
    return buffer.toString().trim();
  }
}

/// The Automated Experiment Harness Runner.
class BenchmarkRunner {
  final List<BenchmarkTrialResult> results = [];

  /// Executes all benchmark scenarios.
  Future<void> runAll({bool runLiveCli = false}) async {
    print('\n===================================================================================================');
    print('                      FLUTTER SANITY MCP AUTOMATED BENCHMARK SUITE                                 ');
    print('===================================================================================================\n');

    // 1. Synthetic Fixture Benchmarks (Reproducible Baseline)
    _benchmarkRenderFlexOverflow();
    _benchmarkUnboundedConstraints();
    _benchmarkUnitTestAssertion();
    _benchmarkPumpAndSettleTimeout();
    _benchmarkAnalyzeDiagnostics();
    _benchmarkDoomLoopEscalation();

    // 2. Live CLI Benchmark (if requested and flutter is available)
    if (runLiveCli) {
      await _benchmarkLiveFlutterTest();
      await _benchmarkLiveFlutterAnalyze();
    }

    _outputConsoleSummary();
    _writeJsonReport();
    _outputMarkdownTables();
  }

  void _benchmarkRenderFlexOverflow() {
    final rawNdjson = SyntheticFixtures.renderFlexOverflowNdjson;
    final sw = Stopwatch()..start();

    final summary = FlutterTestStreamParser.parse(rawNdjson);
    final sanitizedText = summary.toHighDensityJson();
    sw.stop();

    _recordResult(
      name: 'RenderFlex Overflow (400-line box tree)',
      category: 'test',
      rawText: rawNdjson,
      sanitizedText: sanitizedText,
      elapsedUs: sw.elapsedMicroseconds,
    );
  }

  void _benchmarkUnboundedConstraints() {
    final rawNdjson = SyntheticFixtures.unboundedConstraintsNdjson;
    final sw = Stopwatch()..start();

    final summary = FlutterTestStreamParser.parse(rawNdjson);
    final sanitizedText = summary.toHighDensityJson();
    sw.stop();

    _recordResult(
      name: 'Unbounded Viewport Constraints (ListView in Column)',
      category: 'test',
      rawText: rawNdjson,
      sanitizedText: sanitizedText,
      elapsedUs: sw.elapsedMicroseconds,
    );
  }

  void _benchmarkUnitTestAssertion() {
    final rawNdjson = SyntheticFixtures.unitTestAssertionNdjson;
    final sw = Stopwatch()..start();

    final summary = FlutterTestStreamParser.parse(rawNdjson);
    final sanitizedText = summary.toHighDensityJson();
    sw.stop();

    _recordResult(
      name: 'Unit Test Assertion Failure (Framework Stack Dump)',
      category: 'test',
      rawText: rawNdjson,
      sanitizedText: sanitizedText,
      elapsedUs: sw.elapsedMicroseconds,
    );
  }

  void _benchmarkPumpAndSettleTimeout() {
    final rawNdjson = SyntheticFixtures.pumpAndSettleTimeoutNdjson;
    final sw = Stopwatch()..start();

    final summary = FlutterTestStreamParser.parse(rawNdjson);
    final sanitizedText = summary.toHighDensityJson();
    sw.stop();

    _recordResult(
      name: 'pumpAndSettle Timed Out (Infinite Animation)',
      category: 'test',
      rawText: rawNdjson,
      sanitizedText: sanitizedText,
      elapsedUs: sw.elapsedMicroseconds,
    );
  }

  void _benchmarkAnalyzeDiagnostics() {
    final rawMachine = SyntheticFixtures.analyzeMachineFiftyIssues;
    final sw = Stopwatch()..start();

    final result = AnalyzeSanitizer.sanitize(rawMachine, maxIssues: 5);
    final sanitizedText = result.toCleanSummary();
    sw.stop();

    _recordResult(
      name: 'flutter analyze (50 cascaded diagnostics)',
      category: 'analyze',
      rawText: rawMachine,
      sanitizedText: sanitizedText,
      elapsedUs: sw.elapsedMicroseconds,
    );
  }

  void _benchmarkDoomLoopEscalation() {
    final loopBreaker = LoopBreaker(guardrailThreshold: 2, tripThreshold: 3);
    final rawNdjson = SyntheticFixtures.renderFlexOverflowNdjson;
    final summary = FlutterTestStreamParser.parse(rawNdjson);
    final baseSanitizedJson = summary.toHighDensityJson();
    final failure = summary.failures.first;

    for (int attempt = 1; attempt <= 3; attempt++) {
      final sw = Stopwatch()..start();
      final decision = loopBreaker.processOutput(
        baseSanitizedJson,
        filePath: failure.location ?? 'lib/profile_screen.dart',
        line: 55,
      );
      sw.stop();

      final guardrailLabel = decision.level == BreakerLevel.circuitBreakerTripped
          ? 'CIRCUIT_BREAKER_TRIPPED (Halt Edit)'
          : (decision.level == BreakerLevel.guardrailWarning
              ? 'GUARDRAIL_WARNING (Directive Injected)'
              : 'NORMAL');

      _recordResult(
        name: 'LoopBreaker Doom Loop - Attempt #$attempt',
        category: 'guardrail',
        rawText: rawNdjson,
        sanitizedText: decision.formattedOutput,
        elapsedUs: sw.elapsedMicroseconds,
        guardrailTriggered: guardrailLabel,
        consecutiveFailures: decision.consecutiveMatches,
      );
    }
  }

  Future<void> _benchmarkLiveFlutterTest() async {
    try {
      final cmd = io.Platform.isWindows ? 'flutter.bat' : 'flutter';
      final sw = Stopwatch()..start();
      final result = await io.Process.run(cmd, ['test', '--machine', 'test/test_sanitizer_test.dart']);
      sw.stop();

      final rawStdout = result.stdout as String;
      if (rawStdout.isNotEmpty) {
        final parseSw = Stopwatch()..start();
        final summary = FlutterTestStreamParser.parse(rawStdout);
        final sanitized = summary.toHighDensityJson();
        parseSw.stop();

        _recordResult(
          name: 'Live `flutter test --machine` (Self Suite)',
          category: 'live_test',
          rawText: rawStdout,
          sanitizedText: sanitized,
          elapsedUs: parseSw.elapsedMicroseconds,
        );
      }
    } catch (e) {
      print('Skipping live flutter test benchmark: $e');
    }
  }

  Future<void> _benchmarkLiveFlutterAnalyze() async {
    try {
      final cmd = io.Platform.isWindows ? 'flutter.bat' : 'flutter';
      final result = await io.Process.run(cmd, ['analyze', '--machine']);
      final rawStdout = result.stdout as String;
      if (rawStdout.isNotEmpty) {
        final parseSw = Stopwatch()..start();
        final summary = AnalyzeSanitizer.sanitize(rawStdout, maxIssues: 5);
        final sanitized = summary.toCleanSummary();
        parseSw.stop();

        _recordResult(
          name: 'Live `flutter analyze --machine` (Self Project)',
          category: 'live_analyze',
          rawText: rawStdout,
          sanitizedText: sanitized,
          elapsedUs: parseSw.elapsedMicroseconds,
        );
      }
    } catch (e) {
      print('Skipping live flutter analyze benchmark: $e');
    }
  }

  void _recordResult({
    required String name,
    required String category,
    required String rawText,
    required String sanitizedText,
    required int elapsedUs,
    String? guardrailTriggered,
    int consecutiveFailures = 0,
  }) {
    final rawMetrics = PayloadMetrics.fromText(rawText);
    final sanitizedMetrics = PayloadMetrics.fromText(sanitizedText);
    final reduction = ReductionMetrics.compute(rawMetrics, sanitizedMetrics);

    results.add(
      BenchmarkTrialResult(
        scenarioName: name,
        category: category,
        raw: rawMetrics,
        sanitized: sanitizedMetrics,
        reduction: reduction,
        processingTimeMicroseconds: elapsedUs,
        guardrailTriggered: guardrailTriggered,
        consecutiveFailures: consecutiveFailures,
      ),
    );
  }

  // --- Output Formatters ---

  void _outputConsoleSummary() {
    print('═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════');
    print('                                FLUTTER SANITY MCP EMPIRICAL BENCHMARK RESULTS                                         ');
    print('═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════');
    print('${_pad("Scenario", 48)} | ${_pad("Raw Tok", 8)} | ${_pad("San Tok", 8)} | ${_pad("Reduction", 10)} | ${_pad("Overhead", 9)} | Guardrail');
    print('-----------------------------------------------------------------------------------------------------------------------');

    for (final r in results) {
      final name = _pad(r.scenarioName, 48);
      final rawTok = _pad(r.raw.tokens.toString(), 8);
      final sanTok = _pad(r.sanitized.tokens.toString(), 8);
      final redPct = _pad('${r.reduction.tokenReductionPct.toStringAsFixed(1)}%', 10);
      final timeStr = _pad('${r.processingTimeMs.toStringAsFixed(2)}ms', 9);
      final guardrail = r.guardrailTriggered ?? 'None';

      print('$name | $rawTok | $sanTok | $redPct | $timeStr | $guardrail');
    }
    print('═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════\n');
  }

  void _writeJsonReport() {
    final totalRawTokens = results.fold<int>(0, (sum, r) => sum + r.raw.tokens);
    final totalSanitizedTokens = results.fold<int>(0, (sum, r) => sum + r.sanitized.tokens);
    final overallSavingsPct = totalRawTokens == 0 ? 0.0 : ((totalRawTokens - totalSanitizedTokens) / totalRawTokens) * 100.0;

    final jsonMap = {
      'metadata': {
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'platform': io.Platform.operatingSystem,
        'dartVersion': io.Platform.version,
        'charsPerTokenRatio': TokenEstimator.charsPerToken,
      },
      'aggregate': {
        'totalScenarios': results.length,
        'totalRawTokens': totalRawTokens,
        'totalSanitizedTokens': totalSanitizedTokens,
        'totalTokensSaved': totalRawTokens - totalSanitizedTokens,
        'overallTokenReductionPct': double.parse(overallSavingsPct.toStringAsFixed(2)),
      },
      'results': results.map((r) => r.toJson()).toList(),
    };

    final file = io.File('benchmark_results.json');
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(jsonMap));
    print('📄 Saved raw benchmark data to ${file.absolute.path}');
  }

  void _outputMarkdownTables() {
    final sb = StringBuffer();
    sb.writeln('### 📊 Empirical Noise & Token Reduction Benchmark\n');
    sb.writeln('| Scenario / Test Type | Raw Output | Sanitized Output | Token Savings | Processing Overhead | Guardrail Status |');
    sb.writeln('| :--- | :--- | :--- | :--- | :--- | :--- |');

    for (final r in results) {
      final rawCol = '${r.raw.tokens} tok (${r.raw.lines} lines)';
      final sanCol = '**${r.sanitized.tokens} tok** (${r.sanitized.lines} lines)';
      final redCol = '**${r.reduction.tokenReductionPct.toStringAsFixed(1)}%**';
      
      String guard;
      if (r.guardrailTriggered == null) {
        guard = '`Signal Pass`';
      } else if (r.guardrailTriggered == 'NORMAL') {
        guard = '`NORMAL`';
      } else if (r.guardrailTriggered!.contains('CIRCUIT_BREAKER_TRIPPED')) {
        guard = '`🛑 ${r.guardrailTriggered}`';
      } else {
        guard = '`⚠️ ${r.guardrailTriggered}`';
      }

      sb.writeln('| ${r.scenarioName} | $rawCol | $sanCol | $redCol | ${r.processingTimeMs.toStringAsFixed(2)} ms | $guard |');
    }

    print('\n📋 Markdown Table Ready for README.md & Launch:\n');
    print(sb.toString());
  }

  String _pad(String s, int width) {
    if (s.length > width) return '${s.substring(0, width - 3)}...';
    return s.padRight(width);
  }
}

/// Standalone entrypoint for CLI execution.
void main(List<String> args) async {
  final runLive = args.contains('--live');
  final runner = BenchmarkRunner();
  await runner.runAll(runLiveCli: runLive);
}
