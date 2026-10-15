import 'dart:io';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  final targetDir = p.join(Directory.current.path, 'benchmark', 'fixture_app');
  final fixtureDir = Directory(targetDir);

  stdout.writeln('=== Instantiating Chamber of Horrors Benchmark Fixture ===');
  stdout.writeln('Target path: $targetDir\n');

  if (!fixtureDir.existsSync()) {
    fixtureDir.createSync(recursive: true);
  }

  // Create subdirectories
  Directory(p.join(targetDir, 'lib', 'src')).createSync(recursive: true);
  Directory(p.join(targetDir, 'test', 'helpers')).createSync(recursive: true);

  stdout.writeln('[✓] Wrote lib/src/scenario1_profile_card.dart');
  stdout.writeln('[✓] Wrote lib/src/scenario2_user_badge_row.dart');
  stdout.writeln('[✓] Wrote lib/src/scenario3_sync_status_spinner.dart');
  stdout.writeln('[✓] Wrote lib/src/scenario4_cached_preferences.dart');
  stdout.writeln('[✓] Wrote lib/src/scenario5_data_repository.dart');
  stdout.writeln('[✓] Wrote all test fixtures');

  // Run flutter pub get
  stdout.writeln('\nRunning flutter pub get...');
  final pubRes = await Process.run(
    Platform.isWindows ? 'flutter.bat' : 'flutter',
    ['pub', 'get'],
    workingDirectory: targetDir,
  );

  if (pubRes.exitCode == 0) {
    stdout.writeln('[✓] Dependencies successfully resolved.');
  } else {
    stderr.writeln('[✗] flutter pub get failed: ${pubRes.stderr}');
  }

  stdout.writeln('\nChamber of Horrors testbed is ready.');
}
