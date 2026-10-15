import 'dart:io';
import 'package:args/args.dart';
import 'package:flutter_sanity_mcp/src/cli/config_merger.dart';
import 'package:flutter_sanity_mcp/src/cli/path_resolver.dart';

void main(List<String> args) {
  final parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show command usage and available options.',
    )
    ..addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview configuration changes without writing to disk.',
    )
    ..addFlag(
      'global',
      abbr: 'g',
      negatable: false,
      help: 'Configure only global editor configs.',
    )
    ..addFlag(
      'project',
      abbr: 'p',
      negatable: false,
      help: 'Configure only project-level configs in the target directory.',
    )
    ..addFlag(
      'all',
      abbr: 'a',
      negatable: false,
      help: 'Configure all supported editors (creates configs even if not pre-detected).',
    )
    ..addOption(
      'editor',
      abbr: 'e',
      help:
          'Target a specific editor (e.g. cursor, vscode, claude-code, claude-desktop, windsurf, antigravity).',
    )
    ..addOption(
      'dir',
      abbr: 'd',
      help: 'Custom project directory for project-level configs.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Display verbose output including skipped editors.',
    );

  final ArgResults results;
  try {
    results = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}\n');
    stderr.writeln(parser.usage);
    exit(64);
  }

  if (results['help'] as bool) {
    stdout.writeln('flutter-sanity-mcp Auto-Setup CLI');
    stdout.writeln(
        'Automatically detects installed AI editors and registers flutter-sanity-mcp.\n');
    stdout.writeln('Usage: dart run flutter_sanity_mcp:setup [options]\n');
    stdout.writeln(parser.usage);
    exit(0);
  }

  final isDryRun = results['dry-run'] as bool;
  final onlyGlobal = results['global'] as bool;
  final onlyProject = results['project'] as bool;
  final includeAll = results['all'] as bool;
  final editorFilter = results['editor'] as String?;
  final customDir = results['dir'] as String?;
  final isVerbose = results['verbose'] as bool;

  final projectDir = customDir ?? Directory.current.path;
  final resolver = PathResolver(currentDirectory: projectDir);
  final merger = const ConfigMerger();

  stdout.writeln('==================================================');
  stdout.writeln('  flutter-sanity-mcp Auto-Setup');
  stdout.writeln('==================================================');
  stdout.writeln('Detecting installed AI editors and MCP configurations...\n');

  final allTargets = resolver.resolveAllTargets(projectDir: projectDir);
  List<EditorTarget> selectedTargets;

  if (editorFilter != null && editorFilter.isNotEmpty) {
    selectedTargets = resolver.findTargets(editorFilter, projectDir: projectDir);
    if (selectedTargets.isEmpty) {
      stderr.writeln('Error: No editor found matching "$editorFilter".');
      stderr.writeln(
          'Supported editors: cursor, claude-code, claude-desktop, vscode, windsurf, antigravity');
      exit(1);
    }
  } else if (includeAll) {
    selectedTargets = allTargets;
  } else if (onlyGlobal) {
    selectedTargets = allTargets
        .where((t) => t.scope == ConfigScope.global && t.isDetected)
        .toList();
  } else if (onlyProject) {
    selectedTargets = allTargets
        .where((t) => t.scope == ConfigScope.project)
        .toList();
  } else {
    // Default: auto-detect installed global editors and existing project configs
    selectedTargets = allTargets.where((t) => t.isDetected).toList();
  }

  final skippedTargets = allTargets
      .where((t) => !selectedTargets.any((s) => s.id == t.id))
      .toList();

  if (selectedTargets.isEmpty) {
    stdout.writeln('No installed AI editors were automatically detected.');
    stdout.writeln(
        'Use --all to configure all supported editors or --editor <name> for a specific one.\n');
    if (skippedTargets.isNotEmpty) {
      stdout.writeln('Available editors:');
      for (final t in skippedTargets) {
        stdout.writeln('  - ${t.displayName} (${t.configPath})');
      }
    }
    exit(0);
  }

  var successCount = 0;
  var alreadyConfiguredCount = 0;
  var failureCount = 0;

  for (final target in selectedTargets) {
    final result = merger.mergeFile(
      filePath: target.configPath,
      preferredRootKey: target.defaultRootKey,
      dryRun: isDryRun,
    );

    if (result.isSuccess) {
      successCount++;
      if (isDryRun) {
        stdout.writeln('[DRY RUN] ${target.displayName}');
        stdout.writeln('    Path:   ${target.configPath}');
        stdout.writeln('    Key:    "${result.rootKeyUsed}"');
        stdout.writeln(
            '    Action: ${result.alreadyUpToDate ? "Already up to date" : (result.wasCreated ? "Would create" : "Would update")}');
      } else if (result.alreadyUpToDate) {
        alreadyConfiguredCount++;
        stdout.writeln('[✓] ${target.displayName}');
        stdout.writeln('    Path:   ${target.configPath}');
        stdout.writeln(
            '    Status: flutter-sanity-mcp is already configured under "${result.rootKeyUsed}"');
      } else if (result.wasCreated) {
        stdout.writeln('[✓] ${target.displayName}');
        stdout.writeln('    Path:   ${target.configPath}');
        stdout.writeln(
            '    Status: Config created with flutter-sanity-mcp under "${result.rootKeyUsed}"');
      } else {
        stdout.writeln('[✓] ${target.displayName}');
        stdout.writeln('    Path:   ${target.configPath}');
        stdout.writeln(
            '    Status: Registered flutter-sanity-mcp under "${result.rootKeyUsed}"');
        if (result.backupPath != null) {
          stdout.writeln('    Backup: ${result.backupPath}');
        }
      }
    } else {
      failureCount++;
      stdout.writeln('[✗] ${target.displayName}');
      stdout.writeln('    Path:  ${target.configPath}');
      stdout.writeln('    Error: ${result.error}');
    }
    stdout.writeln();
  }

  if (isVerbose && skippedTargets.isNotEmpty) {
    stdout.writeln('Skipped editors (not detected):');
    for (final skipped in skippedTargets) {
      stdout.writeln('[-] ${skipped.displayName}: Not detected');
    }
    stdout.writeln();
  }

  stdout.writeln('==================================================');
  if (isDryRun) {
    stdout.writeln(
        'Dry run finished. $successCount editor(s) ready to be configured.');
  } else {
    stdout.writeln(
        'Setup finished: $successCount target(s) configured ($alreadyConfiguredCount already up-to-date, $failureCount failed).');
    stdout.writeln(
        'Restart your editor or reload MCP servers to begin using flutter-sanity-mcp.');
  }
  stdout.writeln('==================================================');

  if (failureCount > 0) {
    exit(1);
  }
}
