import 'dart:convert';
import 'dart:io';
import 'package:flutter_sanity_mcp/src/cli/config_merger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ConfigMerger - JSONC comment stripping and trailing commas', () {
    test('strips single-line and multi-line comments', () {
      const input = '''
      {
        // This is a single-line comment
        "command": "dart", // inline comment
        /* This is a
           multi-line comment */
        "enabled": true
      }
      ''';

      final stripped = ConfigMerger.stripJsonc(input);
      final decoded = jsonDecode(stripped) as Map<String, dynamic>;

      expect(decoded['command'], equals('dart'));
      expect(decoded['enabled'], equals(true));
      expect(stripped.contains('single-line comment'), isFalse);
      expect(stripped.contains('multi-line comment'), isFalse);
    });

    test('preserves comment markers and slashes inside string literals', () {
      const input = '''
      {
        "url": "https://example.com//path/*not_a_comment*/",
        "description": "Text with // two slashes and /* asterisk */",
        "nested": "Escaped \\" quotes \\" with // slashes"
      }
      ''';

      final stripped = ConfigMerger.stripJsonc(input);
      final decoded = jsonDecode(stripped) as Map<String, dynamic>;

      expect(
        decoded['url'],
        equals('https://example.com//path/*not_a_comment*/'),
      );
      expect(
        decoded['description'],
        equals('Text with // two slashes and /* asterisk */'),
      );
      expect(
        decoded['nested'],
        equals('Escaped " quotes " with // slashes'),
      );
    });

    test('strips trailing commas in maps and lists', () {
      const input = '''
      {
        "items": [
          "first",
          "second",
        ],
        "nested": {
          "a": 1,
          "b": 2,
        },
      }
      ''';

      final stripped = ConfigMerger.stripJsonc(input);
      final decoded = jsonDecode(stripped) as Map<String, dynamic>;

      expect(decoded['items'], equals(['first', 'second']));
      expect(decoded['nested'], equals({'a': 1, 'b': 2}));
    });

    test('does not strip commas inside string literals', () {
      const input = '''
      {
        "query": "SELECT * WHERE a = 1, }",
        "listStr": "[1, 2, ]",
        "final": "ok"
      }
      ''';

      final stripped = ConfigMerger.stripJsonc(input);
      final decoded = jsonDecode(stripped) as Map<String, dynamic>;

      expect(decoded['query'], equals('SELECT * WHERE a = 1, }'));
      expect(decoded['listStr'], equals('[1, 2, ]'));
      expect(decoded['final'], equals('ok'));
    });

    test('handles empty and whitespace-only inputs safely', () {
      expect(ConfigMerger.stripJsonc(''), equals('{}'));
      expect(ConfigMerger.stripJsonc('   \n\t  '), equals('{}'));
      expect(ConfigMerger.stripJsonc('// just a comment\n'), equals('{}'));
    });
  });

  group('ConfigMerger - Non-destructive merging', () {
    final merger = const ConfigMerger();

    test('preserves existing root keys and other configured servers', () {
      final existingConfig = {
        'version': '1.2.0',
        'theme': 'dark',
        'mcpServers': {
          'figma': {
            'command': 'cmd.exe',
            'args': ['/c', 'npx', 'figma-developer-mcp'],
          },
          'github': {
            'command': 'docker',
            'args': ['run', 'gh-mcp'],
          },
        },
      };

      final merged = merger.mergeConfigMap(
        existingConfig: existingConfig,
        preferredRootKey: 'mcpServers',
      );

      // Verify other root keys are preserved
      expect(merged['version'], equals('1.2.0'));
      expect(merged['theme'], equals('dark'));

      // Verify other servers are preserved
      final servers = merged['mcpServers'] as Map<String, dynamic>;
      expect(servers.containsKey('figma'), isTrue);
      expect(servers.containsKey('github'), isTrue);
      expect(servers['figma']['command'], equals('cmd.exe'));

      // Verify flutter-sanity-mcp was injected
      expect(servers.containsKey('flutter-sanity-mcp'), isTrue);
      expect(servers['flutter-sanity-mcp']['command'], equals('dart'));
      expect(
        servers['flutter-sanity-mcp']['args'],
        equals(['pub', 'global', 'run', 'flutter_sanity_mcp:mcp']),
      );
    });

    test('merges cleanly into empty config', () {
      final merged = merger.mergeConfigMap(
        existingConfig: {},
        preferredRootKey: 'mcpServers',
      );

      expect(merged.containsKey('mcpServers'), isTrue);
      final servers = merged['mcpServers'] as Map<String, dynamic>;
      expect(
        servers['flutter-sanity-mcp'],
        equals(ConfigMerger.defaultServerConfig),
      );
    });

    test('updates existing flutter-sanity-mcp definition without data loss', () {
      final existingConfig = {
        'mcpServers': {
          'flutter-sanity-mcp': {
            'command': 'old_dart',
            'args': ['old_arg'],
          },
          'other': {
            'command': 'node',
            'args': ['index.js'],
          },
        },
      };

      final merged = merger.mergeConfigMap(
        existingConfig: existingConfig,
      );

      final servers = merged['mcpServers'] as Map<String, dynamic>;
      expect(servers['other']['command'], equals('node'));
      expect(servers['flutter-sanity-mcp']['command'], equals('dart'));
      expect(
        servers['flutter-sanity-mcp']['args'],
        equals(['pub', 'global', 'run', 'flutter_sanity_mcp:mcp']),
      );
    });
  });

  group('ConfigMerger - Correct root key selection', () {
    test('selects "servers" when existing config already uses "servers"', () {
      final existing = {
        'servers': {
          'copilot-helper': {'command': 'node'},
        },
      };

      final rootKey = ConfigMerger.resolveRootKey(existing);
      expect(rootKey, equals('servers'));

      final merger = const ConfigMerger();
      final merged = merger.mergeConfigMap(existingConfig: existing);
      expect(merged.containsKey('servers'), isTrue);
      expect(merged.containsKey('mcpServers'), isFalse);
    });

    test('selects "mcpServers" when existing config uses "mcpServers"', () {
      final existing = {
        'mcpServers': {
          'my-mcp': {'command': 'python'},
        },
      };

      final rootKey = ConfigMerger.resolveRootKey(
        existing,
        preferredRootKey: 'servers',
      );
      expect(rootKey, equals('mcpServers'));

      final merger = const ConfigMerger();
      final merged = merger.mergeConfigMap(
        existingConfig: existing,
        preferredRootKey: 'servers',
      );
      expect(merged.containsKey('mcpServers'), isTrue);
      expect(merged.containsKey('servers'), isFalse);
    });

    test('selects preferredRootKey "servers" when config is empty (VS Code)', () {
      final rootKey = ConfigMerger.resolveRootKey(
        {},
        preferredRootKey: 'servers',
      );
      expect(rootKey, equals('servers'));

      final merger = const ConfigMerger();
      final merged = merger.mergeConfigMap(
        existingConfig: {},
        preferredRootKey: 'servers',
      );
      expect(merged.containsKey('servers'), isTrue);
      expect(merged.containsKey('mcpServers'), isFalse);
    });

    test('selects preferredRootKey "mcpServers" when config is empty (Cursor/Claude)', () {
      final rootKey = ConfigMerger.resolveRootKey(
        {},
        preferredRootKey: 'mcpServers',
      );
      expect(rootKey, equals('mcpServers'));
    });

    test('defaults to "mcpServers" when no preferred key and no existing keys', () {
      final rootKey = ConfigMerger.resolveRootKey({});
      expect(rootKey, equals('mcpServers'));
    });
  });

  group('ConfigMerger - Backup file creation and atomic write', () {
    late Directory tempDir;
    final merger = const ConfigMerger();

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('config_merger_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('creates .bak backup file when modifying existing config', () {
      final configFile = File(p.join(tempDir.path, 'mcp.json'));
      const originalJson = '''{
  // Original comments
  "mcpServers": {
    "existing": {
      "command": "node"
    }
  }
}''';
      configFile.writeAsStringSync(originalJson);

      final result = merger.mergeFile(
        filePath: configFile.path,
        preferredRootKey: 'mcpServers',
      );

      expect(result.isSuccess, isTrue);
      expect(result.wasUpdated, isTrue);
      expect(result.wasCreated, isFalse);
      expect(result.backupPath, equals('${configFile.path}.bak'));

      // Check backup file exists and matches original content
      final backupFile = File('${configFile.path}.bak');
      expect(backupFile.existsSync(), isTrue);
      expect(backupFile.readAsStringSync(), equals(originalJson));

      // Check target file updated correctly
      final updatedContent = configFile.readAsStringSync();
      final decoded = jsonDecode(updatedContent) as Map<String, dynamic>;
      final servers = decoded['mcpServers'] as Map<String, dynamic>;
      expect(servers.containsKey('existing'), isTrue);
      expect(servers.containsKey('flutter-sanity-mcp'), isTrue);

      // Verify no dangling .tmp file
      final tmpFile = File('${configFile.path}.tmp');
      expect(tmpFile.existsSync(), isFalse);
    });

    test('creates new file without .bak when file did not exist', () {
      final configFile = File(p.join(tempDir.path, 'sub', 'new_mcp.json'));

      final result = merger.mergeFile(
        filePath: configFile.path,
        preferredRootKey: 'servers',
      );

      expect(result.isSuccess, isTrue);
      expect(result.wasCreated, isTrue);
      expect(result.wasUpdated, isFalse);
      expect(result.backupPath, isNull);

      // Verify file was created with "servers" key
      expect(configFile.existsSync(), isTrue);
      final decoded =
          jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
      expect(decoded.containsKey('servers'), isTrue);
      expect(
        decoded['servers']['flutter-sanity-mcp']['command'],
        equals('dart'),
      );

      // Verify no .bak was created
      final backupFile = File('${configFile.path}.bak');
      expect(backupFile.existsSync(), isFalse);
    });

    test('detects already up-to-date configuration without redundant overwrite', () {
      final configFile = File(p.join(tempDir.path, 'up_to_date_mcp.json'));
      merger.mergeFile(
        filePath: configFile.path,
        preferredRootKey: 'mcpServers',
      );

      // Second merge should report alreadyUpToDate
      final result2 = merger.mergeFile(
        filePath: configFile.path,
        preferredRootKey: 'mcpServers',
      );

      expect(result2.isSuccess, isTrue);
      expect(result2.alreadyUpToDate, isTrue);
    });

    test('dry-run does not write to disk or create backup', () {
      final configFile = File(p.join(tempDir.path, 'dry_run.json'));
      configFile.writeAsStringSync('{"mcpServers": {}}');

      final result = merger.mergeFile(
        filePath: configFile.path,
        preferredRootKey: 'mcpServers',
        dryRun: true,
      );

      expect(result.isSuccess, isTrue);
      expect(result.wasUpdated, isTrue);

      // Ensure no backup file was written
      final backupFile = File('${configFile.path}.bak');
      expect(backupFile.existsSync(), isFalse);

      // Ensure target file was not modified
      expect(configFile.readAsStringSync(), equals('{"mcpServers": {}}'));
    });
  });
}
