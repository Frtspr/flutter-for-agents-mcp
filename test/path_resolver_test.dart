import 'package:flutter_sanity_mcp/src/cli/path_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('PathResolver - Cross-Platform Detection', () {
    test('resolves macOS paths correctly', () {
      final resolver = PathResolver(
        operatingSystem: 'macos',
        environment: {'HOME': '/Users/alice'},
        currentDirectory: '/Users/alice/projects/my_app',
        fileExists: (path) => false,
        directoryExists: (path) => false,
      );

      final targets = resolver.resolveAllTargets();

      final claudeDesktop =
          targets.firstWhere((t) => t.id == EditorId.claudeDesktop);
      expect(
        claudeDesktop.configPath,
        equals(
          '/Users/alice/Library/Application Support/Claude/claude_desktop_config.json',
        ),
      );

      final vscodeGlobal =
          targets.firstWhere((t) => t.id == EditorId.vscodeCopilotGlobal);
      expect(
        vscodeGlobal.configPath,
        equals(
          '/Users/alice/Library/Application Support/Code/User/mcp.json',
        ),
      );
      expect(vscodeGlobal.defaultRootKey, equals('servers'));

      final cursorGlobal =
          targets.firstWhere((t) => t.id == EditorId.cursorGlobal);
      expect(
        cursorGlobal.configPath,
        equals('/Users/alice/.cursor/mcp.json'),
      );
      expect(cursorGlobal.defaultRootKey, equals('mcpServers'));

      final claudeCode =
          targets.firstWhere((t) => t.id == EditorId.claudeCodeGlobal);
      expect(
        claudeCode.configPath,
        equals('/Users/alice/.claude.json'),
      );

      final windsurf = targets.firstWhere((t) => t.id == EditorId.windsurf);
      expect(
        windsurf.configPath,
        equals('/Users/alice/.codeium/windsurf/mcp_config.json'),
      );

      final antigravity =
          targets.firstWhere((t) => t.id == EditorId.antigravity);
      expect(
        antigravity.configPath,
        equals('/Users/alice/.gemini/config/mcp_config.json'),
      );
    });

    test('resolves Linux paths correctly', () {
      final resolver = PathResolver(
        operatingSystem: 'linux',
        environment: {
          'HOME': '/home/bob',
          'XDG_CONFIG_HOME': '/home/bob/.config',
        },
        currentDirectory: '/home/bob/projects/flutter_app',
        fileExists: (path) => false,
        directoryExists: (path) => false,
      );

      final targets = resolver.resolveAllTargets();

      final claudeDesktop =
          targets.firstWhere((t) => t.id == EditorId.claudeDesktop);
      expect(
        claudeDesktop.configPath,
        equals('/home/bob/.config/Claude/claude_desktop_config.json'),
      );

      final vscodeGlobal =
          targets.firstWhere((t) => t.id == EditorId.vscodeCopilotGlobal);
      expect(
        vscodeGlobal.configPath,
        equals('/home/bob/.config/Code/User/mcp.json'),
      );
    });

    test('resolves Windows paths correctly', () {
      final resolver = PathResolver(
        operatingSystem: 'windows',
        environment: {
          'USERPROFILE': r'C:\Users\Charlie',
          'APPDATA': r'C:\Users\Charlie\AppData\Roaming',
        },
        currentDirectory: r'C:\Users\Charlie\projects\flutter_app',
        fileExists: (path) => false,
        directoryExists: (path) => false,
      );

      final targets = resolver.resolveAllTargets();

      final claudeDesktop =
          targets.firstWhere((t) => t.id == EditorId.claudeDesktop);
      expect(
        claudeDesktop.configPath,
        equals(
          r'C:\Users\Charlie\AppData\Roaming\Claude\claude_desktop_config.json',
        ),
      );

      final vscodeGlobal =
          targets.firstWhere((t) => t.id == EditorId.vscodeCopilotGlobal);
      expect(
        vscodeGlobal.configPath,
        equals(
          r'C:\Users\Charlie\AppData\Roaming\Code\User\mcp.json',
        ),
      );

      final vscodeProject =
          targets.firstWhere((t) => t.id == EditorId.vscodeCopilotProject);
      expect(
        vscodeProject.configPath,
        equals(
          r'C:\Users\Charlie\projects\flutter_app\.vscode\mcp.json',
        ),
      );
      expect(vscodeProject.defaultRootKey, equals('servers'));
    });

    test('detects installed editor when directory exists even if config does not', () {
      final resolver = PathResolver(
        operatingSystem: 'windows',
        environment: {
          'USERPROFILE': r'C:\Users\Charlie',
          'APPDATA': r'C:\Users\Charlie\AppData\Roaming',
        },
        fileExists: (path) => false,
        directoryExists: (path) => path.contains(r'.gemini'),
      );

      final detected = resolver.detectInstalledTargets();
      expect(detected.any((t) => t.id == EditorId.antigravity), isTrue);
      expect(detected.any((t) => t.id == EditorId.cursorGlobal), isFalse);
    });

    test('findTargets filters editors correctly', () {
      final resolver = PathResolver(
        operatingSystem: 'macos',
        environment: {'HOME': '/Users/test'},
      );

      final vscodeMatches = resolver.findTargets('vscode');
      expect(vscodeMatches.length, equals(2)); // Global + Project

      final cursorMatches = resolver.findTargets('cursor');
      expect(cursorMatches.length, equals(2)); // Global + Project

      final antigravityMatches = resolver.findTargets('antigravity');
      expect(antigravityMatches.length, equals(1));
    });
  });
}
