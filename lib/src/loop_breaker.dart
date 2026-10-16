import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'heuristics.dart';

/// Levels of loop breaker intervention.
enum BreakerLevel {
  /// First failure or non-consecutive failure: clean, normal output.
  normal,

  /// Second consecutive identical failure: injects GUARDRAIL_WARNING.
  guardrailWarning,

  /// Third (or more) consecutive identical failure: trips CIRCUIT_BREAKER_TRIPPED.
  circuitBreakerTripped,
}

/// Represents a deterministic fingerprint of a test failure.
class FailureFingerprint {
  final String hash;
  final String category;
  final String normalizedFilePath;
  final int quantizedLine;
  final String errorSignature;
  final String rawPayload;

  const FailureFingerprint({
    required this.hash,
    required this.category,
    required this.normalizedFilePath,
    required this.quantizedLine,
    required this.errorSignature,
    required this.rawPayload,
  });

  @override
  String toString() => hash;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FailureFingerprint &&
          runtimeType == other.runtimeType &&
          hash == other.hash;

  @override
  int get hashCode => hash.hashCode;
}

/// Outcome of recording a failure through the [LoopBreaker].
class BreakerDecision {
  final BreakerLevel level;
  final FailureFingerprint fingerprint;
  final int consecutiveMatches;
  final HeuristicDirective? directive;
  final String? banner;
  final String formattedOutput;

  const BreakerDecision({
    required this.level,
    required this.fingerprint,
    required this.consecutiveMatches,
    required this.formattedOutput,
    this.directive,
    this.banner,
  });

  /// Whether the breaker has escalated to a guardrail warning.
  bool get isGuardrail => level == BreakerLevel.guardrailWarning;

  /// Whether the circuit breaker has tripped (halt condition).
  bool get isTripped => level == BreakerLevel.circuitBreakerTripped;

  /// Whether editing should be stopped immediately.
  bool get shouldHalt => isTripped;
}

/// Deterministic loop breaker and state machine that intercepts repeated
/// test failures, injects actionable heuristic directives, and trips a circuit
/// breaker to prevent doom loops.
class LoopBreaker {
  final int windowSize;
  final int guardrailThreshold;
  final int tripThreshold;

  final List<FailureFingerprint> _history = [];
  FailureFingerprint? _lastFingerprint;
  int _consecutiveFailures = 0;
  BreakerLevel _currentLevel = BreakerLevel.normal;

  LoopBreaker({
    this.windowSize = 10,
    this.guardrailThreshold = 2,
    this.tripThreshold = 3,
  });

  /// Current consecutive failure count for the matching fingerprint.
  int get consecutiveFailures => _consecutiveFailures;

  /// Current level of the loop breaker state machine.
  BreakerLevel get currentLevel => _currentLevel;

  /// The most recent failure fingerprint, if any.
  FailureFingerprint? get lastFingerprint => _lastFingerprint;

  /// Unmodifiable view of the sliding window history.
  List<FailureFingerprint> get history => List.unmodifiable(_history);

  /// Whether the circuit breaker is currently tripped.
  bool get isTripped => _currentLevel == BreakerLevel.circuitBreakerTripped;

  /// Whether the breaker is currently at the guardrail warning level.
  bool get isGuardrail => _currentLevel == BreakerLevel.guardrailWarning;

  /// Quantize line number by 5 to prevent churn caused by slight line shifts.
  /// (e.g. lines 20-24 all map to 20, lines 25-29 all map to 25).
  static int quantizeLine(int? line, {int bucketSize = 5}) {
    if (line == null || line <= 0) return 0;
    return (line ~/ bucketSize) * bucketSize;
  }

  /// Normalize a file path across platforms and URI formats:
  /// - Converts Windows backslashes `\` to `/`
  /// - Strips `file:///` and `./` prefixes
  /// - Lowercases drive letters and path
  static String normalizeFilePath(String path) {
    if (path.isEmpty) return 'unknown';
    var p = path.trim().replaceAll(r'\', '/');

    if (p.startsWith('file:///')) {
      p = p.substring(8);
    } else if (p.startsWith('file://')) {
      p = p.substring(7);
    }

    if (p.startsWith('./')) {
      p = p.substring(2);
    }

    // Normalize Windows drive letter: C:/ -> c:/
    if (p.length >= 2 && p[1] == ':') {
      p = '${p[0].toLowerCase()}:${p.substring(2)}';
    }

    return p.toLowerCase();
  }

  /// Normalize error signature to remove variable numeric noise
  /// (e.g. float pixel counts, memory addresses, timestamps).
  static String normalizeSignature(String signature) {
    var s = signature.trim().toLowerCase();
    // Normalize pixel overflow amounts (e.g., "by 42.0 pixels" -> "by [px] pixels")
    s = s.replaceAll(
      RegExp(r'by\s+[0-9]+(?:\.[0-9]+)?\s+pixels'),
      'by [px] pixels',
    );
    // Normalize hex memory addresses (e.g., 0x1234abcd)
    s = s.replaceAll(RegExp(r'0x[0-9a-fA-F]+'), '[addr]');
    // Normalize elapsed timestamps
    s = s.replaceAll(RegExp(r'timed out after\s+[0-9:\.]+'), 'timed out');
    // Normalize multiple whitespaces
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }

  /// Compute deterministic failure fingerprint:
  /// `MD5(category + normalizedFilePath + quantizedLine + errorSignature)`
  static FailureFingerprint createFingerprint({
    required String category,
    required String filePath,
    required int line,
    required String errorSignature,
  }) {
    final normCategory = category.trim().toLowerCase();
    final normPath = normalizeFilePath(filePath);
    final qLine = quantizeLine(line);
    final normSignature = normalizeSignature(errorSignature);

    final rawPayload = '$normCategory:$normPath:$qLine:$normSignature';
    final hash = md5.convert(utf8.encode(rawPayload)).toString();

    return FailureFingerprint(
      hash: hash,
      category: normCategory,
      normalizedFilePath: normPath,
      quantizedLine: qLine,
      errorSignature: normSignature,
      rawPayload: rawPayload,
    );
  }

  /// Convenience helper to compute just the MD5 hash string.
  static String computeFingerprintHash({
    required String category,
    required String filePath,
    required int line,
    required String errorSignature,
  }) {
    return createFingerprint(
      category: category,
      filePath: filePath,
      line: line,
      errorSignature: errorSignature,
    ).hash;
  }

  /// Record a test failure into the state machine and return the resulting decision.
  BreakerDecision recordFailure({
    required FailureFingerprint fingerprint,
    HeuristicDirective? directive,
    String rawOutput = '',
  }) {
    if (_lastFingerprint != null &&
        _lastFingerprint!.hash == fingerprint.hash) {
      _consecutiveFailures++;
    } else {
      _consecutiveFailures = 1;
      _lastFingerprint = fingerprint;
    }

    _history.add(fingerprint);
    if (_history.length > windowSize) {
      _history.removeAt(0);
    }

    if (_consecutiveFailures >= tripThreshold) {
      _currentLevel = BreakerLevel.circuitBreakerTripped;
    } else if (_consecutiveFailures >= guardrailThreshold) {
      _currentLevel = BreakerLevel.guardrailWarning;
    } else {
      _currentLevel = BreakerLevel.normal;
    }

    final effectiveDirective = directive ?? Heuristics.genericFallback();
    final banner = _buildBanner(_currentLevel, fingerprint, effectiveDirective);
    final formattedOutput = _buildFormattedOutput(rawOutput, banner);

    return BreakerDecision(
      level: _currentLevel,
      fingerprint: fingerprint,
      consecutiveMatches: _consecutiveFailures,
      directive: effectiveDirective,
      banner: banner,
      formattedOutput: formattedOutput,
    );
  }

  /// Process raw test output end-to-end:
  /// Detects heuristics, extracts location, generates fingerprint, and advances the state machine.
  BreakerDecision processOutput(
    String rawOutput, {
    String? filePath,
    int? line,
    String? category,
    String? errorSignature,
  }) {
    final analysis = Heuristics.analyze(
      rawOutput,
      fallbackFilePath: filePath,
      fallbackLine: line,
    );

    final resolvedCategory = category ?? analysis.category.id;
    final resolvedPath = filePath ?? analysis.location?.filePath ?? 'unknown';
    final resolvedLine = line ?? analysis.location?.line ?? 0;
    final resolvedSignature = errorSignature ?? analysis.errorSignature;

    final fingerprint = createFingerprint(
      category: resolvedCategory,
      filePath: resolvedPath,
      line: resolvedLine,
      errorSignature: resolvedSignature,
    );

    return recordFailure(
      fingerprint: fingerprint,
      directive: analysis.directive,
      rawOutput: rawOutput,
    );
  }

  /// Reset the state machine on a successful test pass.
  void recordSuccess() {
    _consecutiveFailures = 0;
    _lastFingerprint = null;
    _currentLevel = BreakerLevel.normal;
    _history.clear();
  }

  /// Explicitly reset the state machine.
  void reset() => recordSuccess();

  /// Build banner for guardrail warning or circuit breaker trip.
  String? _buildBanner(
    BreakerLevel level,
    FailureFingerprint fingerprint,
    HeuristicDirective directive,
  ) {
    switch (level) {
      case BreakerLevel.normal:
        return null;

      case BreakerLevel.guardrailWarning:
        return '''
================================================================================
[GUARDRAIL_WARNING] Repeated failure detected (attempt #$_consecutiveFailures).
Fingerprint: ${fingerprint.hash}
File: ${fingerprint.normalizedFilePath} (quantized line: ${fingerprint.quantizedLine})

Consecutive failure detected. Review the actionable directive before making another edit:
--------------------------------------------------------------------------------
$directive
================================================================================''';

      case BreakerLevel.circuitBreakerTripped:
        return '''
================================================================================
[CIRCUIT_BREAKER_TRIPPED] Circuit breaker tripped! $_consecutiveFailures consecutive identical failures.
Fingerprint: ${fingerprint.hash}
File: ${fingerprint.normalizedFilePath} (quantized line: ${fingerprint.quantizedLine})

STRICT STOP-EDITING INSTRUCTIONS:
1. STOP making blind code modifications to ${fingerprint.normalizedFilePath}.
2. DO NOT retry the previous edit. Your last 2 attempts failed with the identical fingerprint.
3. Re-read the test requirements, check widget constraints, or revert your recent edits.
4. Follow this heuristic directive before running the test again:
--------------------------------------------------------------------------------
$directive
================================================================================''';
    }
  }

  /// Assemble the formatted output with banner injected if present.
  String _buildFormattedOutput(String rawOutput, String? banner) {
    if (banner == null || banner.isEmpty) {
      return rawOutput;
    }
    if (rawOutput.isEmpty) {
      return banner;
    }
    return '$banner\n\n$rawOutput';
  }
}
