import 'dart:convert';

/// Represents a single diagnostic issue from `dart analyze` or `flutter analyze`.
class DiagnosticIssue {
  final String code;
  final String severity;
  final String? type;
  final String file;
  final int line;
  final int column;
  final int? length;
  final String message;
  final String? correction;
  final int originalIndex;

  const DiagnosticIssue({
    required this.code,
    required this.severity,
    this.type,
    required this.file,
    required this.line,
    required this.column,
    this.length,
    required this.message,
    this.correction,
    this.originalIndex = 0,
  });

  /// Aliases matching `dart analyze --format=json` specification.
  String get problemMessage => message;
  String? get correctionMessage => correction;
  int get startLine => line;
  int get startColumn => column;

  /// Priority for sorting: ERROR (1) > WARNING (2) > INFO/HINT (3) > Other (4).
  int get severityPriority {
    switch (severity.toUpperCase()) {
      case 'ERROR':
        return 1;
      case 'WARNING':
        return 2;
      case 'INFO':
      case 'HINT':
        return 3;
      default:
        return 4;
    }
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'code': code,
      'severity': severity.toUpperCase(),
      'file': file,
      'line': line,
      'column': column,
      'location': {
        'file': file,
        'startLine': line,
        'startColumn': column,
      },
      'message': message,
      'problemMessage': message,
    };
    if (type != null && type!.isNotEmpty) {
      map['type'] = type;
    }
    if (length != null && length! > 0) {
      map['length'] = length;
    }
    if (correction != null && correction!.isNotEmpty) {
      map['correction'] = correction;
      map['correctionMessage'] = correction;
    }
    return map;
  }

  String toFormattedString() {
    final buffer =
        StringBuffer('[$severity] $file:$line:$column - $message ($code)');
    if (correction != null && correction!.isNotEmpty) {
      buffer.write('\n  Fix: $correction');
    }
    return buffer.toString();
  }

  @override
  String toString() => toFormattedString();
}

/// Structured summary of an analysis run ready for AI models.
class AnalyzeResult {
  final bool success;
  final int totalIssues;
  final int errorCount;
  final int warningCount;
  final int infoCount;
  final List<DiagnosticIssue> issues;
  final int hiddenCount;
  final String? hiddenSummary;
  final String summary;

  const AnalyzeResult({
    required this.success,
    required this.totalIssues,
    required this.errorCount,
    required this.warningCount,
    required this.infoCount,
    required this.issues,
    required this.hiddenCount,
    this.hiddenSummary,
    required this.summary,
  });

  bool get hasErrors => errorCount > 0;
  bool get hasWarnings => warningCount > 0;
  bool get isClean => totalIssues == 0;

  Map<String, dynamic> toJson() => {
        'success': success,
        'totalIssues': totalIssues,
        'errorCount': errorCount,
        'warningCount': warningCount,
        'infoCount': infoCount,
        'issues': issues.map((e) => e.toJson()).toList(),
        'hiddenCount': hiddenCount,
        if (hiddenSummary != null) 'hiddenSummary': hiddenSummary,
        'summary': summary,
      };

  String toJsonString({bool pretty = false}) {
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(toJson());
    }
    return jsonEncode(toJson());
  }

  /// Generates a clean human-readable and AI-friendly text summary.
  String toCleanSummary() {
    if (totalIssues == 0) {
      return 'No issues found.';
    }
    final buffer = StringBuffer();
    for (final issue in issues) {
      buffer.writeln(
          '[${issue.severity.toUpperCase()}] ${issue.file}:${issue.line}:${issue.column} - ${issue.message} (${issue.code})');
      if (issue.correction != null && issue.correction!.isNotEmpty) {
        buffer.writeln('  Fix: ${issue.correction}');
      }
    }
    if (hiddenSummary != null && hiddenSummary!.isNotEmpty) {
      buffer.writeln(hiddenSummary);
    }
    return buffer.toString().trimRight();
  }

  @override
  String toString() => toCleanSummary();
}

typedef AnalyzeSanitizerResult = AnalyzeResult;

/// Sanitizer that parses `dart analyze` / `flutter analyze` output,
/// filters noise, and groups diagnostics by severity to prevent context poisoning.
class AnalyzeSanitizer {
  final int defaultMaxIssues;

  const AnalyzeSanitizer({this.defaultMaxIssues = 5});

  // Negative lookbehind (?<!\\)\| to handle escaped pipes safely.
  static final RegExp _machinePipeRegex = RegExp(r'(?<!\\)\|');

  // Human-readable format regex fallback
  static final RegExp _humanFormatRegex = RegExp(
    r'^\s*(error|warning|info)\s*[-•]\s*(.*?)\s*[-•]\s*([^:]+):(\d+):(\d+)\s*[-•]\s*([a-zA-Z0-9_]+)',
    caseSensitive: false,
  );

  /// Sanitizes raw analyzer output and returns an [AnalyzeResult].
  ///
  /// Limits the returned issues to [maxIssues] (defaults to 5)
  /// and summarizes remaining issues in [hiddenSummary] to prevent context poisoning.
  static AnalyzeResult sanitize(String rawOutput, {int maxIssues = 5}) {
    final allIssues = parse(rawOutput);

    // Group / Sort diagnostics by severity: ERROR > WARNING > INFO
    final sortedIssues = List<DiagnosticIssue>.from(allIssues)
      ..sort((a, b) {
        final pA = a.severityPriority;
        final pB = b.severityPriority;
        if (pA != pB) {
          return pA.compareTo(pB);
        }
        return a.originalIndex.compareTo(b.originalIndex);
      });

    final totalIssues = sortedIssues.length;
    final errorCount =
        sortedIssues.where((i) => i.severityPriority == 1).length;
    final warningCount =
        sortedIssues.where((i) => i.severityPriority == 2).length;
    final infoCount = sortedIssues.where((i) => i.severityPriority >= 3).length;

    final displayedIssues = sortedIssues.take(maxIssues).toList();
    final hiddenIssues = sortedIssues.skip(maxIssues).toList();
    final hiddenCount = hiddenIssues.length;

    String? hiddenSummary;
    if (hiddenCount > 0) {
      hiddenSummary = _formatHiddenSummary(hiddenIssues);
    }

    final summaryBuffer = StringBuffer();
    if (totalIssues == 0) {
      summaryBuffer.write('No issues found.');
    } else {
      final counts = <String>[];
      if (errorCount > 0) {
        counts.add('$errorCount error${errorCount == 1 ? '' : 's'}');
      }
      if (warningCount > 0) {
        counts.add('$warningCount warning${warningCount == 1 ? '' : 's'}');
      }
      if (infoCount > 0) {
        counts.add('$infoCount info diagnostic${infoCount == 1 ? '' : 's'}');
      }

      summaryBuffer.write(
          'Analysis found $totalIssues issue${totalIssues == 1 ? '' : 's'} (${counts.join(', ')}).');
      if (hiddenCount > 0) {
        summaryBuffer
            .write(' Showing top $maxIssues critical issues.\n$hiddenSummary');
      }
    }

    return AnalyzeResult(
      success: errorCount == 0,
      totalIssues: totalIssues,
      errorCount: errorCount,
      warningCount: warningCount,
      infoCount: infoCount,
      issues: displayedIssues,
      hiddenCount: hiddenCount,
      hiddenSummary: hiddenSummary,
      summary: summaryBuffer.toString(),
    );
  }

  /// Instance method wrapper for [sanitize].
  AnalyzeResult process(String rawOutput, {int? maxIssues}) {
    return sanitize(rawOutput, maxIssues: maxIssues ?? defaultMaxIssues);
  }

  /// Parses all diagnostic issues from [rawOutput] without truncation.
  static List<DiagnosticIssue> parse(String rawOutput) {
    if (rawOutput.trim().isEmpty) return <DiagnosticIssue>[];

    // 1. Try structured JSON format (`dart analyze --format=json`)
    final jsonIssues = _tryParseJson(rawOutput);
    if (jsonIssues != null) {
      return jsonIssues;
    }

    // 2. Try machine pipe-delimited format (`flutter analyze --machine`)
    final machineIssues = _parseMachine(rawOutput);
    if (machineIssues.isNotEmpty) {
      return machineIssues;
    }

    // 3. Fallback to human-readable format if applicable
    final humanIssues = _parseHuman(rawOutput);
    return humanIssues;
  }

  /// Parses structured JSON diagnostics (`dart analyze --format=json`).
  static List<DiagnosticIssue>? _tryParseJson(String rawOutput) {
    final trimmed = rawOutput.trim();
    dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      // Substring extraction if surrounded by extra stdout text
      final startObj = trimmed.indexOf('{');
      final endObj = trimmed.lastIndexOf('}');
      if (startObj != -1 && endObj > startObj) {
        try {
          decoded = jsonDecode(trimmed.substring(startObj, endObj + 1));
        } catch (_) {}
      }
      if (decoded == null) {
        final startArr = trimmed.indexOf('[');
        final endArr = trimmed.lastIndexOf(']');
        if (startArr != -1 && endArr > startArr) {
          try {
            decoded = jsonDecode(trimmed.substring(startArr, endArr + 1));
          } catch (_) {}
        }
      }
    }

    if (decoded == null) return null;

    List<dynamic>? diagList;
    if (decoded is List) {
      diagList = decoded;
    } else if (decoded is Map) {
      if (decoded['diagnostics'] is List) {
        diagList = decoded['diagnostics'] as List;
      } else if (decoded['issues'] is List) {
        diagList = decoded['issues'] as List;
      } else if (decoded.isEmpty || decoded.containsKey('version')) {
        return <DiagnosticIssue>[];
      }
    }

    if (diagList == null) return null;

    final issues = <DiagnosticIssue>[];
    for (var i = 0; i < diagList.length; i++) {
      final item = diagList[i];
      if (item is! Map) continue;

      final code =
          (item['code'] ?? item['errorCode'] ?? item['id'] ?? 'unknown')
              .toString();
      final severity = (item['severity'] ?? 'INFO').toString().toUpperCase();
      final type = item['type']?.toString();
      final message =
          (item['problemMessage'] ?? item['message'] ?? '').toString();
      final correction =
          (item['correctionMessage'] ?? item['correction'])?.toString();

      String file = '';
      int line = 1;
      int column = 1;
      int? length;

      final loc = item['location'];
      if (loc is Map) {
        file = (loc['file'] ?? loc['path'] ?? '').toString();
        if (loc['startLine'] != null) {
          line = _toInt(loc['startLine']) ?? 1;
        } else if (loc['line'] != null) {
          line = _toInt(loc['line']) ?? 1;
        } else if (loc['range'] is Map) {
          final start = loc['range']['start'];
          if (start is Map) {
            line = _toInt(start['line']) ?? 1;
            column = _toInt(start['column']) ?? 1;
          }
        }

        if (loc['startColumn'] != null) {
          column = _toInt(loc['startColumn']) ?? 1;
        } else if (loc['column'] != null) {
          column = _toInt(loc['column']) ?? 1;
        }
      } else {
        file = (item['file'] ?? item['path'] ?? '').toString();
        line = _toInt(item['line']) ?? 1;
        column = _toInt(item['column']) ?? 1;
      }

      if (item['length'] != null) {
        length = _toInt(item['length']);
      }

      issues.add(DiagnosticIssue(
        code: code,
        severity: severity,
        type: type,
        file: file,
        line: line,
        column: column,
        length: length,
        message: message,
        correction: correction,
        originalIndex: i,
      ));
    }
    return issues;
  }

  /// Parses pipe-delimited machine format:
  /// `SEVERITY|TYPE|ERROR_CODE|FILE_PATH|LINE|COLUMN|LENGTH|ERROR_MESSAGE`
  ///
  /// Uses negative lookbehind `(?<!\\)\|` to avoid splitting on escaped pipes.
  static List<DiagnosticIssue> _parseMachine(String rawOutput) {
    final lines = rawOutput.split(RegExp(r'\r?\n'));
    final issues = <DiagnosticIssue>[];
    var index = 0;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final parts = line.split(_machinePipeRegex);
      if (parts.length < 8) {
        continue;
      }

      final rawSeverity = parts[0].trim().toUpperCase();
      if (!const {'ERROR', 'WARNING', 'INFO', 'HINT'}.contains(rawSeverity)) {
        continue;
      }

      final severity = rawSeverity == 'HINT' ? 'INFO' : rawSeverity;
      final type = parts[1].trim();
      final code = parts[2].trim();
      final file = parts[3].trim();
      final lineNum = int.tryParse(parts[4].trim()) ?? 1;
      final columnNum = int.tryParse(parts[5].trim()) ?? 1;
      final length = int.tryParse(parts[6].trim());

      // Join remaining parts if any and unescape escaped pipes \| -> |
      final rawMessage = parts.sublist(7).join('|').trim();
      final message = rawMessage.replaceAll(r'\|', '|');

      issues.add(DiagnosticIssue(
        code: code,
        severity: severity,
        type: type,
        file: file,
        line: lineNum,
        column: columnNum,
        length: length,
        message: message,
        originalIndex: index++,
      ));
    }
    return issues;
  }

  /// Parses human-readable analyzer fallback output.
  static List<DiagnosticIssue> _parseHuman(String rawOutput) {
    final lines = rawOutput.split(RegExp(r'\r?\n'));
    final issues = <DiagnosticIssue>[];
    var index = 0;

    for (final rawLine in lines) {
      final match = _humanFormatRegex.firstMatch(rawLine);
      if (match != null) {
        final severity = match.group(1)!.toUpperCase();
        final message = match.group(2)!.trim();
        final file = match.group(3)!.trim();
        final lineNum = int.tryParse(match.group(4)!) ?? 1;
        final colNum = int.tryParse(match.group(5)!) ?? 1;
        final code = match.group(6)!.trim();

        issues.add(DiagnosticIssue(
          code: code,
          severity: severity,
          file: file,
          line: lineNum,
          column: colNum,
          message: message,
          originalIndex: index++,
        ));
      }
    }
    return issues;
  }

  static String _formatHiddenSummary(List<DiagnosticIssue> hidden) {
    if (hidden.isEmpty) return '';
    final count = hidden.length;
    final errors = hidden.where((i) => i.severityPriority == 1).length;
    final warnings = hidden.where((i) => i.severityPriority == 2).length;
    final infos = hidden.where((i) => i.severityPriority >= 3).length;

    if (errors == 0 && infos == 0) {
      return '... and $count more warnings hidden to prevent context poisoning';
    } else if (errors == 0 && warnings == 0) {
      return '... and $count more info diagnostics hidden to prevent context poisoning';
    } else if (warnings == 0 && infos == 0) {
      return '... and $count more errors hidden to prevent context poisoning';
    } else {
      final parts = <String>[];
      if (errors > 0) parts.add('$errors errors');
      if (warnings > 0) parts.add('$warnings warnings');
      if (infos > 0) parts.add('$infos infos');
      return '... and $count more issues (${parts.join(', ')}) hidden to prevent context poisoning';
    }
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// Convenience top-level function for sanitizing analyzer output.
AnalyzeResult sanitizeAnalyzeOutput(String rawOutput, {int maxIssues = 5}) {
  return AnalyzeSanitizer.sanitize(rawOutput, maxIssues: maxIssues);
}
