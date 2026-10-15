import 'dart:io' as io;
import 'package:flutter_sanity_mcp/flutter_sanity_mcp.dart';
import 'setup.dart' as setup_cmd;
import 'mcp.dart' as mcp_cmd;

void main(List<String> args) async {
  if (args.isEmpty || args.contains('-h') || args.contains('--help')) {
    _printUsage();
    return;
  }

  final command = args.first.toLowerCase();
  final subArgs = args.sublist(1);

  switch (command) {
    case 'setup':
      setup_cmd.main(subArgs);
      break;

    case 'mcp':
      await mcp_cmd.main(subArgs);
      break;

    case 'doctor':
      await _runDoctor();
      break;

    case 'test':
      await _runTestCli(subArgs);
      break;

    case 'analyze':
      await _runAnalyzeCli(subArgs);
      break;

    default:
      io.stderr.writeln('Unknown command: "$command"');
      _printUsage();
      io.exit(1);
  }
}

void _printUsage() {
  io.stdout.writeln('''
flutter_sanity - High-density AI agent guardian for Flutter & Dart.

Usage: flutter_sanity <command> [arguments]

Available Commands:
  setup     Automatically register flutter-sanity-mcp in Cursor, Claude, VS Code, etc.
  mcp       Launch the stdio Model Context Protocol (MCP) server.
  doctor    Verify Flutter SDK, Dart environment, and MCP configurations.
  test      Run smart test runner with 95% stack pruning and doom-loop detection.
  analyze   Run smart analyze with top-issue prioritization and secondary noise squashing.

Flags:
  -h, --help    Show this help message.

Examples:
  flutter_sanity setup
  flutter_sanity setup --dry-run
  flutter_sanity mcp
  flutter_sanity test test/widget_test.dart
  flutter_sanity analyze
''');
}

Future<void> _runDoctor() async {
  io.stdout.writeln('=== Flutter Sanity Doctor ===\n');

  // Check Dart SDK
  try {
    final dartRes = await io.Process.run(io.Platform.isWindows ? 'dart.bat' : 'dart', ['--version']);
    io.stdout.writeln('[✓] Dart SDK: ${(dartRes.stdout.toString() + dartRes.stderr.toString()).trim()}');
  } catch (_) {
    io.stdout.writeln('[✗] Dart SDK not found in PATH');
  }

  // Check Flutter SDK
  try {
    final flutterRes = await io.Process.run(io.Platform.isWindows ? 'flutter.bat' : 'flutter', ['--version']);
    final firstLine = (flutterRes.stdout.toString()).split('\n').first.trim();
    io.stdout.writeln('[✓] Flutter SDK: $firstLine');
  } catch (_) {
    io.stdout.writeln('[✗] Flutter SDK not found in PATH');
  }

  io.stdout.writeln('\nRun "flutter_sanity setup" to install or update editor integrations.');
}

Future<void> _runTestCli(List<String> args) async {
  final target = args.isNotEmpty ? args.first : 'test';
  io.stdout.writeln('Running smart tests for: $target ...\n');

  final flutterCmd = io.Platform.isWindows ? 'flutter.bat' : 'flutter';
  final process = await io.Process.start(
    flutterCmd,
    ['test', '--machine', target],
  );

  final parser = FlutterTestStreamParser();
  process.stdout.transform(io.systemEncoding.decoder).listen(parser.feedOutput);
  final exitCode = await process.exitCode;

  final summary = parser.finish();
  io.stdout.writeln(summary.toHighDensityJson());
  io.exit(exitCode);
}

Future<void> _runAnalyzeCli(List<String> args) async {
  final target = args.isNotEmpty ? args.first : '.';
  io.stdout.writeln('Running smart analyze for: $target ...\n');

  final dartCmd = io.Platform.isWindows ? 'dart.bat' : 'dart';
  final res = await io.Process.run(
    dartCmd,
    ['analyze', '--format=json', target],
  );

  final analyzeResult = AnalyzeSanitizer.sanitize(res.stdout as String);
  io.stdout.writeln(analyzeResult.toCleanSummary());
  io.exit(analyzeResult.success ? 0 : 1);
}
