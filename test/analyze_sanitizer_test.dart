import 'dart:convert';
import 'package:test/test.dart';
import 'package:flutter_sanity_mcp/flutter_sanity_mcp.dart';

void main() {
  group('AnalyzeSanitizer', () {
    group('Structured JSON output parsing (dart analyze --format=json)', () {
      test('parses diagnostics with location.startLine and location.startColumn', () {
        const sampleJson = '''
{
  "version": 1,
  "diagnostics": [
    {
      "code": "undefined_identifier",
      "severity": "ERROR",
      "type": "COMPILE_TIME_ERROR",
      "location": {
        "file": "lib/main.dart",
        "startLine": 10,
        "startColumn": 5
      },
      "problemMessage": "Undefined name 'foo'.",
      "correctionMessage": "Try declaring 'foo' before using it."
    },
    {
      "code": "unused_import",
      "severity": "WARNING",
      "type": "LINT",
      "location": {
        "file": "lib/utils.dart",
        "startLine": 1,
        "startColumn": 8
      },
      "problemMessage": "Unused import: 'dart:async'.",
      "correctionMessage": "Try removing the import."
    }
  ]
}
''';

        final result = AnalyzeSanitizer.sanitize(sampleJson);

        expect(result.totalIssues, equals(2));
        expect(result.errorCount, equals(1));
        expect(result.warningCount, equals(1));
        expect(result.infoCount, equals(0));
        expect(result.hasErrors, isTrue);
        expect(result.success, isFalse);
        expect(result.issues.length, equals(2));

        final errorIssue = result.issues[0];
        expect(errorIssue.code, equals('undefined_identifier'));
        expect(errorIssue.severity, equals('ERROR'));
        expect(errorIssue.type, equals('COMPILE_TIME_ERROR'));
        expect(errorIssue.file, equals('lib/main.dart'));
        expect(errorIssue.line, equals(10));
        expect(errorIssue.column, equals(5));
        expect(errorIssue.startLine, equals(10));
        expect(errorIssue.startColumn, equals(5));
        expect(errorIssue.problemMessage, equals("Undefined name 'foo'."));
        expect(errorIssue.correctionMessage, equals("Try declaring 'foo' before using it."));

        final warningIssue = result.issues[1];
        expect(warningIssue.code, equals('unused_import'));
        expect(warningIssue.severity, equals('WARNING'));
        expect(warningIssue.file, equals('lib/utils.dart'));
        expect(warningIssue.line, equals(1));
        expect(warningIssue.column, equals(8));
      });

      test('parses location.range format and handles empty diagnostics', () {
        const rangeJson = '''
{
  "version": 1,
  "diagnostics": [
    {
      "code": "avoid_print",
      "severity": "INFO",
      "location": {
        "file": "lib/logger.dart",
        "range": {
          "start": { "offset": 50, "line": 4, "column": 3 },
          "end": { "offset": 60, "line": 4, "column": 13 }
        }
      },
      "problemMessage": "Avoid 'print' calls in production code."
    }
  ]
}
''';
        final result = AnalyzeSanitizer.sanitize(rangeJson);
        expect(result.totalIssues, equals(1));
        expect(result.infoCount, equals(1));
        expect(result.errorCount, equals(0));
        expect(result.success, isTrue);
        expect(result.issues[0].file, equals('lib/logger.dart'));
        expect(result.issues[0].line, equals(4));
        expect(result.issues[0].column, equals(3));

        const emptyJson = '{"version": 1, "diagnostics": []}';
        final cleanResult = AnalyzeSanitizer.sanitize(emptyJson);
        expect(cleanResult.totalIssues, equals(0));
        expect(cleanResult.isClean, isTrue);
        expect(cleanResult.success, isTrue);
      });
    });

    group('Machine pipe-delimited format (flutter analyze --machine)', () {
      test('parses standard machine pipe format with noise filtering', () {
        const machineOutput = '''
Analyzing flutter_sanity_mcp...
ERROR|COMPILE_TIME_ERROR|UNDEFINED_IDENTIFIER|lib/src/runner.dart|42|7|4|Undefined name 'task'
WARNING|STATIC_WARNING|DEAD_CODE|lib/src/runner.dart|50|3|10|Dead code
INFO|LINT|avoid_print|lib/main.dart|15|1|12|Avoid 'print' calls in production code.
3 issues found.
''';

        final result = AnalyzeSanitizer.sanitize(machineOutput);

        expect(result.totalIssues, equals(3));
        expect(result.errorCount, equals(1));
        expect(result.warningCount, equals(1));
        expect(result.infoCount, equals(1));
        expect(result.issues[0].code, equals('UNDEFINED_IDENTIFIER'));
        expect(result.issues[0].severity, equals('ERROR'));
        expect(result.issues[0].file, equals('lib/src/runner.dart'));
        expect(result.issues[0].line, equals(42));
        expect(result.issues[0].column, equals(7));
        expect(result.issues[0].length, equals(4));
        expect(result.issues[0].message, equals("Undefined name 'task'"));
      });

      test('safely parses escaped pipes in messages without breaking fields', () {
        const escapedPipeOutput =
            r'ERROR|COMPILE_TIME_ERROR|TYPE_MISMATCH|lib/api.dart|88|12|15|Expected type A \| B but found C \| D';

        final result = AnalyzeSanitizer.sanitize(escapedPipeOutput);

        expect(result.totalIssues, equals(1));
        final issue = result.issues[0];
        expect(issue.code, equals('TYPE_MISMATCH'));
        expect(issue.file, equals('lib/api.dart'));
        expect(issue.line, equals(88));
        expect(issue.column, equals(12));
        expect(issue.length, equals(15));
        // The escaped pipe \| must be unescaped to regular | in message
        expect(issue.message, equals('Expected type A | B but found C | D'));
      });
    });

    group('Anti-Context Poisoning & Truncation (Top N critical issues)', () {
      test('groups by severity (ERROR > WARNING > INFO) and limits to top 5', () {
        // Build 47 diagnostics: 2 ERRORs and 45 WARNINGs
        final diagnostics = <Map<String, dynamic>>[];

        // Add 20 warnings first
        for (var i = 1; i <= 20; i++) {
          diagnostics.add({
            'code': 'warning_code_$i',
            'severity': 'WARNING',
            'location': {'file': 'lib/file_$i.dart', 'startLine': i, 'startColumn': 1},
            'problemMessage': 'Warning message $i',
          });
        }

        // Add 2 critical errors later
        diagnostics.add({
          'code': 'critical_error_1',
          'severity': 'ERROR',
          'location': {'file': 'lib/core.dart', 'startLine': 100, 'startColumn': 5},
          'problemMessage': 'Fatal type mismatch',
          'correctionMessage': 'Change type to int',
        });
        diagnostics.add({
          'code': 'critical_error_2',
          'severity': 'ERROR',
          'location': {'file': 'lib/core.dart', 'startLine': 105, 'startColumn': 8},
          'problemMessage': 'Method not found',
        });

        // Add remaining 25 warnings
        for (var i = 21; i <= 45; i++) {
          diagnostics.add({
            'code': 'warning_code_$i',
            'severity': 'WARNING',
            'location': {'file': 'lib/file_$i.dart', 'startLine': i, 'startColumn': 1},
            'problemMessage': 'Warning message $i',
          });
        }

        final rawJson = jsonEncode({'version': 1, 'diagnostics': diagnostics});
        final result = AnalyzeSanitizer.sanitize(rawJson);

        // 47 total issues
        expect(result.totalIssues, equals(47));
        expect(result.errorCount, equals(2));
        expect(result.warningCount, equals(45));

        // Truncated to top 5
        expect(result.issues.length, equals(5));

        // Critical ERRORs must be prioritized at the top
        expect(result.issues[0].severity, equals('ERROR'));
        expect(result.issues[0].code, equals('critical_error_1'));
        expect(result.issues[1].severity, equals('ERROR'));
        expect(result.issues[1].code, equals('critical_error_2'));

        // Next 3 items must be top warnings
        expect(result.issues[2].severity, equals('WARNING'));
        expect(result.issues[3].severity, equals('WARNING'));
        expect(result.issues[4].severity, equals('WARNING'));

        // 42 warnings squashed in 1 line
        expect(result.hiddenCount, equals(42));
        expect(
          result.hiddenSummary,
          equals('... and 42 more warnings hidden to prevent context poisoning'),
        );
      });

      test('supports custom maxIssues limit', () {
        final diagnostics = List.generate(
          10,
          (i) => {
            'code': 'code_$i',
            'severity': i == 0 ? 'ERROR' : 'WARNING',
            'location': {'file': 'lib/test.dart', 'startLine': i + 1, 'startColumn': 1},
            'problemMessage': 'Issue $i',
          },
        );

        final rawJson = jsonEncode({'diagnostics': diagnostics});
        final result = AnalyzeSanitizer.sanitize(rawJson, maxIssues: 2);

        expect(result.issues.length, equals(2));
        expect(result.hiddenCount, equals(8));
        expect(
          result.hiddenSummary,
          equals('... and 8 more warnings hidden to prevent context poisoning'),
        );
      });

      test('does not truncate when issue count <= maxIssues', () {
        final diagnostics = [
          {
            'code': 'unused_local_variable',
            'severity': 'INFO',
            'location': {'file': 'lib/a.dart', 'startLine': 1, 'startColumn': 1},
            'problemMessage': 'Local variable is unused',
          }
        ];

        final result = AnalyzeSanitizer.sanitize(jsonEncode({'diagnostics': diagnostics}));
        expect(result.issues.length, equals(1));
        expect(result.hiddenCount, equals(0));
        expect(result.hiddenSummary, isNull);
      });
    });

    group('Clean summary formatting & AI ready JSON', () {
      test('toCleanSummary produces concise formatting with squashed line', () {
        final diagnostics = <Map<String, dynamic>>[];
        diagnostics.add({
          'code': 'undefined_function',
          'severity': 'ERROR',
          'location': {'file': 'lib/main.dart', 'startLine': 10, 'startColumn': 3},
          'problemMessage': "Undefined function 'runApp'.",
          'correctionMessage': "Import 'package:flutter/material.dart'.",
        });

        for (var i = 1; i <= 6; i++) {
          diagnostics.add({
            'code': 'unused_import',
            'severity': 'WARNING',
            'location': {'file': 'lib/util.dart', 'startLine': i, 'startColumn': 1},
            'problemMessage': 'Unused import $i',
          });
        }

        final result = AnalyzeSanitizer.sanitize(jsonEncode({'diagnostics': diagnostics}), maxIssues: 3);
        final cleanSummary = result.toCleanSummary();

        // Must include the error with fix
        expect(cleanSummary, contains("[ERROR] lib/main.dart:10:3 - Undefined function 'runApp'. (undefined_function)"));
        expect(cleanSummary, contains("Fix: Import 'package:flutter/material.dart'."));

        // Must contain the hidden count line
        expect(cleanSummary, contains('... and 4 more warnings hidden to prevent context poisoning'));
      });

      test('toCleanSummary formats clean analysis when no issues', () {
        final result = AnalyzeSanitizer.sanitize('{"diagnostics": []}');
        expect(result.toCleanSummary(), equals('No issues found.'));
      });

      test('produces structured JSON output ready for AI models', () {
        const sampleJson = '''
{
  "diagnostics": [
    {
      "code": "missing_return",
      "severity": "ERROR",
      "location": {
        "file": "lib/calc.dart",
        "startLine": 25,
        "startColumn": 1
      },
      "problemMessage": "This function must return a value of type int."
    }
  ]
}
''';
        final result = AnalyzeSanitizer.sanitize(sampleJson);
        final jsonMap = result.toJson();

        expect(jsonMap['success'], isFalse);
        expect(jsonMap['totalIssues'], equals(1));
        expect(jsonMap['errorCount'], equals(1));
        expect(jsonMap['warningCount'], equals(0));
        expect(jsonMap['infoCount'], equals(0));
        expect(jsonMap['hiddenCount'], equals(0));
        expect(jsonMap['issues'], isA<List>());
        expect(jsonMap['issues'][0]['code'], equals('missing_return'));
        expect(jsonMap['issues'][0]['severity'], equals('ERROR'));
        expect(jsonMap['issues'][0]['location']['file'], equals('lib/calc.dart'));
        expect(jsonMap['issues'][0]['location']['startLine'], equals(25));
        expect(jsonMap['issues'][0]['location']['startColumn'], equals(1));
        expect(jsonMap['issues'][0]['problemMessage'], equals('This function must return a value of type int.'));

        // Validate json serialization
        final serialized = result.toJsonString();
        final deserialized = jsonDecode(serialized) as Map<String, dynamic>;
        expect(deserialized['totalIssues'], equals(1));
        expect(deserialized['errorCount'], equals(1));
      });
    });
  });
}
