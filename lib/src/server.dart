import 'dart:convert';
import 'dart:io' as io;
import 'package:dart_mcp/server.dart';
import 'package:flutter_sanity_mcp/src/test_sanitizer.dart';
import 'package:flutter_sanity_mcp/src/analyze_sanitizer.dart';
import 'package:flutter_sanity_mcp/src/loop_breaker.dart';

/// Production MCP Server for Flutter & Dart AI coding agents.
base class FlutterSanityServer extends MCPServer
    with ToolsSupport, LoggingSupport {
  final LoopBreaker loopBreaker;
  int _testsExecuted = 0;
  int _analysesExecuted = 0;
  int _estimatedTokensSaved = 0;

  FlutterSanityServer(
    super.channel, {
    LoopBreaker? loopBreaker,
  })  : loopBreaker = loopBreaker ?? LoopBreaker(),
        super.fromStreamChannel(
          implementation: Implementation(
            name: 'flutter-sanity-mcp',
            version: '1.0.0',
            description:
                'High-density MCP server for Flutter & Dart. Strips 95% stack trace noise and halts agent doom loops.',
          ),
          instructions:
              'Always use run_smart_test and run_smart_analyze instead of raw bash flutter test or flutter analyze to save context tokens and avoid hallucinatory doom loops.',
        ) {
    _registerAllTools();
  }

  void _registerAllTools() {
    _registerSmartTest();
    _registerSmartAnalyze();
    _registerSanityHealth();
  }

  void _registerSmartTest() {
    final tool = Tool(
      name: 'run_smart_test',
      title: 'Run Smart Flutter Test',
      description:
          'Runs Flutter tests via machine NDJSON stream, purges 95% of internal framework stack traces, squashes RenderObject trees, and intercepts doom loops with deterministic guardrails.',
      inputSchema: Schema.object(
        properties: {
          'path': Schema.string(
            description:
                'Target test file or folder (e.g. test/widget_test.dart). Defaults to "test".',
          ),
          'name': Schema.string(
            description: 'Filter tests by regex matching test name (--name).',
          ),
          'tags': Schema.string(
            description: 'Filter tests by tag (--tags).',
          ),
          'timeout_seconds': Schema.int(
            description: 'Process timeout in seconds. Defaults to 60.',
          ),
        },
      ),
    );

    registerTool(tool, (request) async {
      final args = request.arguments ?? {};
      final testPath = (args['path'] as String?)?.trim() ?? 'test';
      final nameFilter = args['name'] as String?;
      final tagsFilter = args['tags'] as String?;
      final timeoutSec = (args['timeout_seconds'] as int?) ?? 60;

      _testsExecuted++;

      try {
        final processArgs = ['test', '--machine'];
        if (nameFilter != null && nameFilter.isNotEmpty) {
          processArgs.addAll(['--name', nameFilter]);
        }
        if (tagsFilter != null && tagsFilter.isNotEmpty) {
          processArgs.addAll(['--tags', tagsFilter]);
        }
        processArgs.add(testPath);

        final flutterCmd = io.Platform.isWindows ? 'flutter.bat' : 'flutter';
        final process = await io.Process.start(
          flutterCmd,
          processArgs,
          mode: io.ProcessStartMode.normal,
        );

        final parser = FlutterTestStreamParser();
        final rawStderrBuffer = StringBuffer();

        process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(parser.feedLine);

        process.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          rawStderrBuffer.writeln(line);
        });

        final exitCode = await process.exitCode.timeout(
          Duration(seconds: timeoutSec),
          onTimeout: () {
            process.kill(io.ProcessSignal.sigkill);
            return -1;
          },
        );

        final summary = parser.finish();

        // Estimate token savings: raw stdout would be ~3000 tokens for failures, summary is ~150 tokens
        if (!summary.success) {
          _estimatedTokensSaved += 2850;
        } else {
          _estimatedTokensSaved += 400;
          loopBreaker.recordSuccess();
        }

        // Check each failure with LoopBreaker
        final guardrailAlerts = <String>[];
        bool shouldHalt = false;

        for (final failure in summary.failures) {
          final errorSnippet = failure.error;
          final location = failure.location ?? failure.test;
          final processed = loopBreaker.processOutput(
            '$errorSnippet\n$location\n${failure.stack.join('\n')}',
          );

          if (processed.banner != null) {
            guardrailAlerts.add(processed.banner!);
            if (processed.level == BreakerLevel.circuitBreakerTripped) {
              shouldHalt = true;
            }
          }
        }

        final responseBuffer = StringBuffer();
        if (guardrailAlerts.isNotEmpty) {
          responseBuffer.writeln(guardrailAlerts.join('\n\n'));
          responseBuffer.writeln('----------------------------------------');
        }

        responseBuffer.writeln(summary.toHighDensityJson());

        if (exitCode == -1) {
          responseBuffer.writeln(
              '\n[WARNING: Process timed out after $timeoutSec seconds]');
        }

        final rawStderr = rawStderrBuffer.toString().trim();
        if (rawStderr.isNotEmpty && !summary.success) {
          responseBuffer.writeln('\n[System Stderr]:');
          responseBuffer.writeln(rawStderr);
        }

        return CallToolResult(
          isError: !summary.success || shouldHalt,
          content: [
            TextContent(text: responseBuffer.toString()),
          ],
        );
      } catch (e, st) {
        return CallToolResult(
          isError: true,
          content: [
            TextContent(text: 'Failed to execute flutter test: $e\n$st'),
          ],
        );
      }
    });
  }

  void _registerSmartAnalyze() {
    final tool = Tool(
      name: 'run_smart_analyze',
      title: 'Run Smart Flutter / Dart Analyze',
      description:
          'Runs dart analyze or flutter analyze, prioritizes critical errors, squashes secondary noise, and prevents context poisoning.',
      inputSchema: Schema.object(
        properties: {
          'path': Schema.string(
            description:
                'Target directory or file to analyze. Defaults to current directory (".").',
          ),
          'max_issues': Schema.int(
            description: 'Maximum issues to return in detail. Defaults to 5.',
          ),
        },
      ),
    );

    registerTool(tool, (request) async {
      final args = request.arguments ?? {};
      final targetPath = (args['path'] as String?)?.trim() ?? '.';
      final maxIssues = (args['max_issues'] as int?) ?? 5;

      _analysesExecuted++;

      try {
        // Step 1: Try dart analyze --format=json
        final dartCmd = io.Platform.isWindows ? 'dart.bat' : 'dart';
        final result = await io.Process.run(
          dartCmd,
          ['analyze', '--format=json', targetPath],
        );

        final rawStdout = result.stdout as String;
        AnalyzeResult analyzeResult;

        if (rawStdout.trim().startsWith('{')) {
          analyzeResult = AnalyzeSanitizer.sanitize(
            rawStdout,
            maxIssues: maxIssues,
          );
        } else {
          // Step 2: Fallback to flutter analyze --machine
          final flutterCmd = io.Platform.isWindows ? 'flutter.bat' : 'flutter';
          final flutterResult = await io.Process.run(
            flutterCmd,
            ['analyze', '--machine', targetPath],
          );
          analyzeResult = AnalyzeSanitizer.sanitize(
            flutterResult.stdout as String,
            maxIssues: maxIssues,
          );
        }

        if (analyzeResult.totalIssues > maxIssues) {
          _estimatedTokensSaved += (analyzeResult.totalIssues - maxIssues) * 60;
        }

        return CallToolResult(
          isError: !analyzeResult.success,
          content: [
            TextContent(text: analyzeResult.toCleanSummary()),
          ],
        );
      } catch (e, st) {
        return CallToolResult(
          isError: true,
          content: [
            TextContent(text: 'Failed to run analyze: $e\n$st'),
          ],
        );
      }
    });
  }

  void _registerSanityHealth() {
    final tool = Tool(
      name: 'get_sanity_health',
      title: 'Get Sanity Health & Metrics',
      description:
          'Returns current session statistics, loop breaker status, and estimated token savings.',
      inputSchema: Schema.object(properties: {}),
    );

    registerTool(tool, (request) async {
      final data = {
        'status': 'healthy',
        'testsExecuted': _testsExecuted,
        'analysesExecuted': _analysesExecuted,
        'estimatedTokensSaved': _estimatedTokensSaved,
        'loopBreakerConsecutiveFailures': loopBreaker.consecutiveFailures,
        'loopBreakerLevel': loopBreaker.currentLevel.name,
      };

      const encoder = JsonEncoder.withIndent('  ');
      return CallToolResult(
        isError: false,
        content: [
          TextContent(text: encoder.convert(data)),
        ],
      );
    });
  }
}
