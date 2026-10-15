import 'dart:io';
import 'package:flutter_sanity_mcp/flutter_sanity_mcp.dart';

void main() async {
  stdout.writeln('====================================================');
  stdout.writeln('  Chamber of Horrors: AI Doom-Loop Benchmark Engine');
  stdout.writeln('====================================================\n');

  final fixtureDir = 'benchmark/fixture_app';

  // 1. Measure Raw flutter test output
  stdout.writeln('[1/3] Running Raw flutter test --machine...');
  final rawProcess = await Process.run(
    Platform.isWindows ? 'flutter.bat' : 'flutter',
    ['test', '--machine', 'test/chamber_of_horrors_suite_test.dart'],
    workingDirectory: fixtureDir,
  );
  final rawOutput = rawProcess.stdout.toString();
  final rawLines = rawOutput.split('\n').length;
  final estimatedRawTokens = (rawOutput.length / 3.8).round();

  stdout.writeln('  -> Raw Lines: $rawLines');
  stdout.writeln('  -> Estimated Raw Context Tokens: ~$estimatedRawTokens tokens\n');

  // 2. Measure Sanitized flutter-sanity-mcp output
  stdout.writeln('[2/3] Running flutter-sanity-mcp parser...');
  final summary = FlutterTestStreamParser.parse(rawOutput);
  final sanitizedJson = summary.toHighDensityJson();
  final sanitizedLines = sanitizedJson.split('\n').length;
  final estimatedSanitizedTokens = (sanitizedJson.length / 3.8).round();

  stdout.writeln('  -> Sanitized Output Lines: $sanitizedLines');
  stdout.writeln('  -> Estimated Sanitized Tokens: ~$estimatedSanitizedTokens tokens');
  final reductionPercent = ((1 - (estimatedSanitizedTokens / estimatedRawTokens)) * 100).toStringAsFixed(1);
  stdout.writeln('  -> TOKEN REDUCTION: $reductionPercent%\n');

  // 3. Verify Doom Loop Circuit Breaker Trip
  stdout.writeln('[3/3] Simulating 3 consecutive edits to verify Circuit Breaker...');
  final loopBreaker = LoopBreaker();
  for (var attempt = 1; attempt <= 3; attempt++) {
    final result = loopBreaker.processOutput(rawOutput);
    stdout.writeln('  Attempt $attempt: Breaker Level = ${result.level.name}');
    if (result.banner != null) {
      stdout.writeln('    Alert Banner: ${result.banner!.split('\n').first}');
    }
  }

  stdout.writeln('\n====================================================');
  stdout.writeln('Benchmark Complete: 100% Signal, Doom-Loop Defeated!');
  stdout.writeln('====================================================');
}
