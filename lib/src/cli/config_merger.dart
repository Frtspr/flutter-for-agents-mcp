import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Result of an MCP configuration merge operation.
class MergeResult {
  final String filePath;
  final String? backupPath;
  final bool wasCreated;
  final bool wasUpdated;
  final bool alreadyUpToDate;
  final String rootKeyUsed;
  final String? error;

  const MergeResult({
    required this.filePath,
    this.backupPath,
    this.wasCreated = false,
    this.wasUpdated = false,
    this.alreadyUpToDate = false,
    required this.rootKeyUsed,
    this.error,
  });

  bool get isSuccess => error == null;

  @override
  String toString() {
    if (!isSuccess) return 'MergeResult(error: $error)';
    if (alreadyUpToDate) {
      return 'MergeResult(already up-to-date at $filePath)';
    }
    if (wasCreated) {
      return 'MergeResult(created at $filePath, key: $rootKeyUsed)';
    }
    return 'MergeResult(updated at $filePath, backup: $backupPath, key: $rootKeyUsed)';
  }
}

/// Handles non-destructive merging of MCP server configurations.
class ConfigMerger {
  final String serverName;
  final Map<String, dynamic> serverConfig;

  static const String defaultServerName = 'flutter-sanity-mcp';

  static const Map<String, dynamic> defaultServerConfig = {
    'command': 'dart',
    'args': ['pub', 'global', 'run', 'flutter_sanity_mcp:mcp'],
  };

  const ConfigMerger({
    this.serverName = defaultServerName,
    this.serverConfig = defaultServerConfig,
  });

  /// Strips JSONC comments (`/* ... */` and `// ...`) and trailing commas before `}` or `]`.
  ///
  /// String literals and escaped quotes (`\"`) are preserved without corruption.
  static String stripJsonc(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '{}';

    // Pass 1: Strip single-line and multi-line comments outside string literals.
    final pass1 = StringBuffer();
    var inString = false;
    var stringEscape = false;
    final len = input.length;
    var i = 0;

    while (i < len) {
      final char = input[i];

      if (inString) {
        pass1.write(char);
        if (stringEscape) {
          stringEscape = false;
        } else if (char == '\\') {
          stringEscape = true;
        } else if (char == '"') {
          inString = false;
        }
        i++;
      } else {
        if (char == '"') {
          inString = true;
          stringEscape = false;
          pass1.write(char);
          i++;
        } else if (char == '/' && i + 1 < len && input[i + 1] == '/') {
          // Skip single-line comment until newline or EOF
          i += 2;
          while (i < len && input[i] != '\n' && input[i] != '\r') {
            i++;
          }
        } else if (char == '/' && i + 1 < len && input[i + 1] == '*') {
          // Skip multi-line comment until */ or EOF
          i += 2;
          while (i + 1 < len && !(input[i] == '*' && input[i + 1] == '/')) {
            i++;
          }
          if (i + 1 < len) {
            i += 2; // skip */
          } else {
            i = len;
          }
        } else {
          pass1.write(char);
          i++;
        }
      }
    }

    final withoutComments = pass1.toString();
    if (withoutComments.trim().isEmpty) return '{}';

    // Pass 2: Remove trailing commas before } or ] outside string literals.
    final pass2 = StringBuffer();
    inString = false;
    stringEscape = false;
    final p2Len = withoutComments.length;
    var j = 0;

    while (j < p2Len) {
      final char = withoutComments[j];

      if (inString) {
        pass2.write(char);
        if (stringEscape) {
          stringEscape = false;
        } else if (char == '\\') {
          stringEscape = true;
        } else if (char == '"') {
          inString = false;
        }
        j++;
      } else {
        if (char == '"') {
          inString = true;
          stringEscape = false;
          pass2.write(char);
          j++;
        } else if (char == ',') {
          // Look ahead past whitespace to check if next non-space char is closing delimiter
          var k = j + 1;
          while (k < p2Len && _isWhitespace(withoutComments[k])) {
            k++;
          }
          if (k < p2Len &&
              (withoutComments[k] == '}' || withoutComments[k] == ']')) {
            // Trailing comma found, drop it
            j++;
          } else {
            pass2.write(char);
            j++;
          }
        } else {
          pass2.write(char);
          j++;
        }
      }
    }

    return pass2.toString().trim();
  }

  static bool _isWhitespace(String char) {
    return char == ' ' || char == '\t' || char == '\n' || char == '\r';
  }

  /// Determines the appropriate root key (`servers` vs `mcpServers`).
  ///
  /// - If `preferredRootKey` is specified and already present, it is used.
  /// - If config contains `mcpServers`, uses `mcpServers`.
  /// - If config contains `servers`, uses `servers`.
  /// - Defaults to `preferredRootKey` if provided, otherwise `'mcpServers'`.
  static String resolveRootKey(
    Map<String, dynamic> config, {
    String? preferredRootKey,
  }) {
    if (preferredRootKey != null && config.containsKey(preferredRootKey)) {
      return preferredRootKey;
    }
    if (config.containsKey('mcpServers')) {
      return 'mcpServers';
    }
    if (config.containsKey('servers')) {
      return 'servers';
    }
    return preferredRootKey ?? 'mcpServers';
  }

  /// Non-destructively merges server definition into an existing config Map.
  ///
  /// Preserves all other root keys and other configured servers.
  Map<String, dynamic> mergeConfigMap({
    required Map<String, dynamic> existingConfig,
    String? preferredRootKey,
  }) {
    final merged = Map<String, dynamic>.from(existingConfig);
    final rootKey = resolveRootKey(merged, preferredRootKey: preferredRootKey);

    final dynamic existingServers = merged[rootKey];
    final Map<String, dynamic> serversMap;
    if (existingServers is Map) {
      serversMap = Map<String, dynamic>.from(existingServers);
    } else {
      serversMap = <String, dynamic>{};
    }

    serversMap[serverName] = Map<String, dynamic>.from(serverConfig);
    merged[rootKey] = serversMap;

    return merged;
  }

  /// Parses JSONC string, non-destructively merges server config, and returns formatted JSON.
  String mergeJsonString({
    required String jsoncContent,
    String? preferredRootKey,
  }) {
    final cleaned = stripJsonc(jsoncContent);
    final dynamic decoded = jsonDecode(cleaned);

    final Map<String, dynamic> configMap;
    if (decoded is Map<String, dynamic>) {
      configMap = decoded;
    } else if (decoded is Map) {
      configMap = Map<String, dynamic>.from(decoded);
    } else {
      configMap = <String, dynamic>{};
    }

    final merged = mergeConfigMap(
      existingConfig: configMap,
      preferredRootKey: preferredRootKey,
    );

    return formatJson(merged);
  }

  /// Formats a Map as pretty-printed JSON with 2 spaces indentation.
  static String formatJson(Map<String, dynamic> jsonMap) {
    const encoder = JsonEncoder.withIndent('  ');
    return '${encoder.convert(jsonMap)}\n';
  }

  /// Performs non-destructive merge into a target file on disk.
  ///
  /// - Strips JSONC comments if file exists.
  /// - Preserves existing servers and settings.
  /// - Creates `<filePath>.bak` backup of original file.
  /// - Performs atomic write via `<filePath>.tmp` and rename.
  MergeResult mergeFile({
    required String filePath,
    String? preferredRootKey,
    bool dryRun = false,
  }) {
    try {
      final file = File(filePath);
      final exists = file.existsSync();
      var wasCreated = false;
      var wasUpdated = false;
      var alreadyUpToDate = false;
      String? backupPath;

      Map<String, dynamic> existingConfig = <String, dynamic>{};

      if (exists) {
        final rawContent = file.readAsStringSync();
        final cleaned = stripJsonc(rawContent);
        final dynamic decoded = jsonDecode(cleaned);
        if (decoded is Map) {
          existingConfig = Map<String, dynamic>.from(decoded);
        }
      }

      final rootKey = resolveRootKey(
        existingConfig,
        preferredRootKey: preferredRootKey,
      );

      // Check if already up-to-date
      if (exists &&
          existingConfig[rootKey] is Map &&
          existingConfig[rootKey][serverName] != null) {
        final existingServer = existingConfig[rootKey][serverName];
        if (_deepEquals(existingServer, serverConfig)) {
          alreadyUpToDate = true;
        }
      }

      final merged = mergeConfigMap(
        existingConfig: existingConfig,
        preferredRootKey: preferredRootKey,
      );

      final formattedJson = formatJson(merged);

      if (dryRun) {
        return MergeResult(
          filePath: filePath,
          backupPath: exists ? '$filePath.bak' : null,
          wasCreated: !exists,
          wasUpdated: exists && !alreadyUpToDate,
          alreadyUpToDate: alreadyUpToDate,
          rootKeyUsed: rootKey,
        );
      }

      // Ensure directory exists
      final dir = Directory(p.dirname(filePath));
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      // Create backup if file exists
      if (exists) {
        backupPath = '$filePath.bak';
        file.copySync(backupPath);
        wasUpdated = !alreadyUpToDate;
      } else {
        wasCreated = true;
      }

      // Atomic write via temporary file
      final tmpFile = File('$filePath.tmp');
      try {
        tmpFile.writeAsStringSync(formattedJson, flush: true);
        try {
          tmpFile.renameSync(filePath);
        } on FileSystemException {
          // On Windows, rename might fail if target exists
          if (file.existsSync()) {
            file.deleteSync();
          }
          tmpFile.renameSync(filePath);
        }
      } finally {
        if (tmpFile.existsSync()) {
          try {
            tmpFile.deleteSync();
          } catch (_) {}
        }
      }

      return MergeResult(
        filePath: filePath,
        backupPath: backupPath,
        wasCreated: wasCreated,
        wasUpdated: wasUpdated,
        alreadyUpToDate: alreadyUpToDate,
        rootKeyUsed: rootKey,
      );
    } catch (e) {
      return MergeResult(
        filePath: filePath,
        rootKeyUsed: preferredRootKey ?? 'mcpServers',
        error: e.toString(),
      );
    }
  }

  static bool _deepEquals(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}
