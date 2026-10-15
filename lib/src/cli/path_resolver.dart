import 'dart:io';
import 'package:path/path.dart' as p;

/// Defines the scope of an editor configuration.
enum ConfigScope {
  global,
  project,
}

/// Identifiers for supported AI editors and tools.
enum EditorId {
  cursorGlobal,
  cursorProject,
  claudeCodeGlobal,
  claudeCodeProject,
  claudeDesktop,
  vscodeCopilotGlobal,
  vscodeCopilotProject,
  windsurf,
  antigravity,
}

/// Represents a targeted editor configuration file and its metadata.
class EditorTarget {
  final EditorId id;
  final String editorName;
  final String displayName;
  final String configPath;
  final String defaultRootKey; // 'mcpServers' or 'servers'
  final ConfigScope scope;
  final bool isDetected;
  final bool configExists;

  const EditorTarget({
    required this.id,
    required this.editorName,
    required this.displayName,
    required this.configPath,
    required this.defaultRootKey,
    required this.scope,
    required this.isDetected,
    required this.configExists,
  });

  @override
  String toString() => '$displayName ($configPath)';
}

/// Signature for checking if a path exists.
typedef PathPredicate = bool Function(String path);

/// Resolves configuration paths and detects installed AI editors.
class PathResolver {
  final Map<String, String> environment;
  final String operatingSystem;
  final PathPredicate _fileExists;
  final PathPredicate _directoryExists;
  final String _currentDirectory;
  late final p.Context _path;

  PathResolver({
    Map<String, String>? environment,
    String? operatingSystem,
    PathPredicate? fileExists,
    PathPredicate? directoryExists,
    String? currentDirectory,
  })  : environment = environment ?? Platform.environment,
        operatingSystem = operatingSystem ?? Platform.operatingSystem,
        _fileExists = fileExists ?? ((path) => File(path).existsSync()),
        _directoryExists =
            directoryExists ?? ((path) => Directory(path).existsSync()),
        _currentDirectory = currentDirectory ?? Directory.current.path {
    _path = p.Context(
      style: isWindows ? p.Style.windows : p.Style.posix,
    );
  }

  bool get isWindows => operatingSystem == 'windows';
  bool get isMacOS => operatingSystem == 'macos';
  bool get isLinux => operatingSystem == 'linux';

  /// Resolves user's home directory across Windows, macOS, and Linux.
  String resolveHomeDir() {
    if (isWindows) {
      final userProfile = environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        return userProfile;
      }
      final homeDrive = environment['HOMEDRIVE'];
      final homePath = environment['HOMEPATH'];
      if (homeDrive != null && homePath != null) {
        return _path.join(homeDrive, homePath);
      }
      return environment['HOME'] ?? '';
    }
    return environment['HOME'] ?? '';
  }

  /// Resolves the OS-specific application data/config directory.
  ///
  /// - Windows: `%APPDATA%` (or `%USERPROFILE%\AppData\Roaming`)
  /// - macOS: `~/Library/Application Support`
  /// - Linux: `$XDG_CONFIG_HOME` (or `~/.config`)
  String resolveAppDataDir() {
    final home = resolveHomeDir();
    if (isWindows) {
      final appData = environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return appData;
      }
      return _path.join(home, 'AppData', 'Roaming');
    } else if (isMacOS) {
      return _path.join(home, 'Library', 'Application Support');
    } else {
      final xdgConfig = environment['XDG_CONFIG_HOME'];
      if (xdgConfig != null && xdgConfig.isNotEmpty) {
        return xdgConfig;
      }
      return _path.join(home, '.config');
    }
  }

  /// Resolves all known editor targets for the specified [projectDir].
  List<EditorTarget> resolveAllTargets({String? projectDir}) {
    final home = resolveHomeDir();
    final appData = resolveAppDataDir();
    final proj = projectDir ?? _currentDirectory;

    final targets = <EditorTarget>[];

    // 1. Cursor (Global)
    final cursorGlobalPath = _path.join(home, '.cursor', 'mcp.json');
    final cursorGlobalDir = _path.join(home, '.cursor');
    final cursorGlobalFileExists = _fileExists(cursorGlobalPath);
    targets.add(
      EditorTarget(
        id: EditorId.cursorGlobal,
        editorName: 'Cursor',
        displayName: 'Cursor (Global)',
        configPath: cursorGlobalPath,
        defaultRootKey: 'mcpServers',
        scope: ConfigScope.global,
        configExists: cursorGlobalFileExists,
        isDetected: cursorGlobalFileExists || _directoryExists(cursorGlobalDir),
      ),
    );

    // 2. Cursor (Project)
    final cursorProjPath = _path.join(proj, '.cursor', 'mcp.json');
    final cursorProjDir = _path.join(proj, '.cursor');
    final cursorProjFileExists = _fileExists(cursorProjPath);
    targets.add(
      EditorTarget(
        id: EditorId.cursorProject,
        editorName: 'Cursor',
        displayName: 'Cursor (Project)',
        configPath: cursorProjPath,
        defaultRootKey: 'mcpServers',
        scope: ConfigScope.project,
        configExists: cursorProjFileExists,
        isDetected: cursorProjFileExists || _directoryExists(cursorProjDir),
      ),
    );

    // 3. Claude Code (Global)
    final claudeCodeGlobalPath = _path.join(home, '.claude.json');
    final claudeCodeDir = _path.join(home, '.claude');
    final claudeCodeGlobalExists = _fileExists(claudeCodeGlobalPath);
    targets.add(
      EditorTarget(
        id: EditorId.claudeCodeGlobal,
        editorName: 'Claude Code',
        displayName: 'Claude Code (Global)',
        configPath: claudeCodeGlobalPath,
        defaultRootKey: 'mcpServers',
        scope: ConfigScope.global,
        configExists: claudeCodeGlobalExists,
        isDetected:
            claudeCodeGlobalExists || _directoryExists(claudeCodeDir),
      ),
    );

    // 4. Claude Code (Project)
    final claudeCodeProjPath = _path.join(proj, '.mcp.json');
    final claudeCodeProjExists = _fileExists(claudeCodeProjPath);
    targets.add(
      EditorTarget(
        id: EditorId.claudeCodeProject,
        editorName: 'Claude Code',
        displayName: 'Claude Code (Project)',
        configPath: claudeCodeProjPath,
        defaultRootKey: 'mcpServers',
        scope: ConfigScope.project,
        configExists: claudeCodeProjExists,
        // For project-level .mcp.json, detected if file exists or project dir exists
        isDetected: claudeCodeProjExists,
      ),
    );

    // 5. Claude Desktop
    final claudeDesktopPath =
        _path.join(appData, 'Claude', 'claude_desktop_config.json');
    final claudeDesktopDir = _path.join(appData, 'Claude');
    final claudeDesktopExists = _fileExists(claudeDesktopPath);
    targets.add(
      EditorTarget(
        id: EditorId.claudeDesktop,
        editorName: 'Claude Desktop',
        displayName: 'Claude Desktop',
        configPath: claudeDesktopPath,
        defaultRootKey: 'mcpServers',
        scope: ConfigScope.global,
        configExists: claudeDesktopExists,
        isDetected:
            claudeDesktopExists || _directoryExists(claudeDesktopDir),
      ),
    );

    // 6. VS Code Copilot (Global) - Root key: "servers"
    var vsCodeUserDir = _path.join(appData, 'Code', 'User');
    var vsCodeGlobalPath = _path.join(vsCodeUserDir, 'mcp.json');
    if (!_directoryExists(vsCodeUserDir) &&
        !_fileExists(vsCodeGlobalPath) &&
        _directoryExists(_path.join(appData, 'Code - Insiders', 'User'))) {
      vsCodeUserDir = _path.join(appData, 'Code - Insiders', 'User');
      vsCodeGlobalPath = _path.join(vsCodeUserDir, 'mcp.json');
    }
    final vsCodeGlobalExists = _fileExists(vsCodeGlobalPath);
    final vsCodeDetected = vsCodeGlobalExists ||
        _directoryExists(vsCodeUserDir) ||
        _directoryExists(_path.join(appData, 'Code')) ||
        _directoryExists(_path.join(appData, 'Code - Insiders'));
    targets.add(
      EditorTarget(
        id: EditorId.vscodeCopilotGlobal,
        editorName: 'VS Code Copilot',
        displayName: 'VS Code Copilot (Global)',
        configPath: vsCodeGlobalPath,
        defaultRootKey: 'servers',
        scope: ConfigScope.global,
        configExists: vsCodeGlobalExists,
        isDetected: vsCodeDetected,
      ),
    );

    // 7. VS Code Copilot (Project) - Root key: "servers"
    final vsCodeProjPath = _path.join(proj, '.vscode', 'mcp.json');
    final vsCodeProjDir = _path.join(proj, '.vscode');
    final vsCodeProjExists = _fileExists(vsCodeProjPath);
    targets.add(
      EditorTarget(
        id: EditorId.vscodeCopilotProject,
        editorName: 'VS Code Copilot',
        displayName: 'VS Code Copilot (Project)',
        configPath: vsCodeProjPath,
        defaultRootKey: 'servers',
        scope: ConfigScope.project,
        configExists: vsCodeProjExists,
        isDetected: vsCodeProjExists || _directoryExists(vsCodeProjDir),
      ),
    );

    // 8. Windsurf (Global)
    final windsurfPath =
        _path.join(home, '.codeium', 'windsurf', 'mcp_config.json');
    final windsurfDir = _path.join(home, '.codeium', 'windsurf');
    final windsurfExists = _fileExists(windsurfPath);
    targets.add(
      EditorTarget(
        id: EditorId.windsurf,
        editorName: 'Windsurf',
        displayName: 'Windsurf (Global)',
        configPath: windsurfPath,
        defaultRootKey: 'mcpServers',
        scope: ConfigScope.global,
        configExists: windsurfExists,
        isDetected: windsurfExists ||
            _directoryExists(windsurfDir) ||
            _directoryExists(_path.join(home, '.codeium')),
      ),
    );

    // 9. Antigravity (Global)
    final antigravityPath =
        _path.join(home, '.gemini', 'config', 'mcp_config.json');
    final antigravityConfigDir = _path.join(home, '.gemini', 'config');
    final antigravityDir = _path.join(home, '.gemini');
    final antigravityExists = _fileExists(antigravityPath);
    targets.add(
      EditorTarget(
        id: EditorId.antigravity,
        editorName: 'Antigravity',
        displayName: 'Antigravity (Global)',
        configPath: antigravityPath,
        defaultRootKey: 'mcpServers',
        scope: ConfigScope.global,
        configExists: antigravityExists,
        isDetected: antigravityExists ||
            _directoryExists(antigravityConfigDir) ||
            _directoryExists(antigravityDir),
      ),
    );

    return targets;
  }

  /// Returns only targets where the editor installation or config file was detected.
  List<EditorTarget> detectInstalledTargets({String? projectDir}) {
    return resolveAllTargets(projectDir: projectDir)
        .where((target) => target.isDetected)
        .toList();
  }

  /// Finds target matching given query string (editor name or id prefix).
  List<EditorTarget> findTargets(String query, {String? projectDir}) {
    final lower = query.toLowerCase().replaceAll(RegExp(r'[-_\s]'), '');
    return resolveAllTargets(projectDir: projectDir).where((target) {
      final idName = target.id.name.toLowerCase();
      final editorName =
          target.editorName.toLowerCase().replaceAll(RegExp(r'[-_\s]'), '');
      final displayName =
          target.displayName.toLowerCase().replaceAll(RegExp(r'[-_\s]'), '');
      return idName.contains(lower) ||
          editorName.contains(lower) ||
          displayName.contains(lower);
    }).toList();
  }
}
