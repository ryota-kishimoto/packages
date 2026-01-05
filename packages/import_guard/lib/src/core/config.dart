import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'pattern_trie.dart';

/// Configuration for import_guard loaded from import_guard.yaml
class ImportGuardConfig {
  final List<String> deny;
  final List<String> allow;
  final String configDir;

  /// Path to the import_guard.yaml file that defined this config.
  final String configFilePath;

  /// Whether to inherit parent directory configs. Defaults to true.
  final bool inherit;

  /// Pre-built Trie for absolute deny patterns (package:, dart:)
  final PatternTrie denyPatternTrie;

  /// Relative deny patterns that need context-aware matching
  final List<String> denyRelativePatterns;

  /// Pre-built Trie for absolute allow patterns (package:, dart:)
  final PatternTrie allowPatternTrie;

  /// Relative allow patterns that need context-aware matching
  final List<String> allowRelativePatterns;

  /// Whether this config has allow rules (used for optimization)
  bool get hasAllowRules => allow.isNotEmpty;

  ImportGuardConfig._({
    required this.deny,
    required this.allow,
    required this.configDir,
    required this.configFilePath,
    required this.inherit,
    required this.denyPatternTrie,
    required this.denyRelativePatterns,
    required this.allowPatternTrie,
    required this.allowRelativePatterns,
  });

  // Legacy getters for backward compatibility
  PatternTrie get absolutePatternTrie => denyPatternTrie;
  List<String> get relativePatterns => denyRelativePatterns;

  factory ImportGuardConfig.fromYaml(
    YamlMap yaml,
    String configDir,
    String configFilePath,
  ) {
    final denyList = yaml['deny'] as YamlList?;
    final denyPatterns = denyList?.map((e) => e.toString()).toList() ?? [];

    final allowList = yaml['allow'] as YamlList?;
    final allowPatterns = allowList?.map((e) => e.toString()).toList() ?? [];

    final inherit = yaml['inherit'] as bool? ?? true;

    // Separate absolute and relative deny patterns
    final denyAbsolutePatterns = <String>[];
    final denyRelativePatterns = <String>[];

    for (final pattern in denyPatterns) {
      if (pattern.startsWith('./') || pattern.startsWith('../')) {
        denyRelativePatterns.add(pattern);
      } else {
        denyAbsolutePatterns.add(pattern);
      }
    }

    // Separate absolute and relative allow patterns
    final allowAbsolutePatterns = <String>[];
    final allowRelativePatterns = <String>[];

    for (final pattern in allowPatterns) {
      if (pattern.startsWith('./') || pattern.startsWith('../')) {
        allowRelativePatterns.add(pattern);
      } else {
        allowAbsolutePatterns.add(pattern);
      }
    }

    // Build Trie from absolute deny patterns
    final denyTrie = PatternTrie();
    for (final pattern in denyAbsolutePatterns) {
      denyTrie.insert(pattern);
    }

    // Build Trie from absolute allow patterns
    final allowTrie = PatternTrie();
    for (final pattern in allowAbsolutePatterns) {
      allowTrie.insert(pattern);
    }

    return ImportGuardConfig._(
      deny: denyPatterns,
      allow: allowPatterns,
      configDir: configDir,
      configFilePath: configFilePath,
      inherit: inherit,
      denyPatternTrie: denyTrie,
      denyRelativePatterns: denyRelativePatterns,
      allowPatternTrie: allowTrie,
      allowRelativePatterns: allowRelativePatterns,
    );
  }
}

/// Cache for import_guard.yaml configurations.
/// Scans all configs once per repo root for better performance.
class ConfigCache {
  static final _instance = ConfigCache._();
  factory ConfigCache() => _instance;
  ConfigCache._();

  /// Map: repoRoot -> (Map: configDir -> config)
  /// Shared across all packages in the same repo.
  final _configsByRepo = <String, Map<String, ImportGuardConfig>>{};

  /// Map: packageRoot -> repoRoot
  final _repoRoots = <String, String>{};

  /// Map: packageRoot -> packageName
  final _packageNames = <String, String?>{};

  /// Get all applicable configs for a file path.
  /// Returns configs from file's directory up to repo root.
  /// Stops traversing if a config has `inherit: false`.
  List<ImportGuardConfig> getConfigsForFile(String filePath, String packageRoot) {
    final repoRoot = _getRepoRoot(packageRoot);
    _ensureRepoLoaded(repoRoot);

    final configs = <ImportGuardConfig>[];
    final allConfigs = _configsByRepo[repoRoot] ?? {};

    var dir = p.dirname(filePath);
    while (true) {
      final config = allConfigs[dir];
      if (config != null) {
        configs.add(config);
        // Stop inheriting if this config has inherit: false
        if (!config.inherit) break;
      }
      if (dir == repoRoot || dir == p.dirname(dir)) break;
      dir = p.dirname(dir);
    }

    return configs;
  }

  /// Get cached package name.
  String? getPackageName(String packageRoot) {
    if (!_packageNames.containsKey(packageRoot)) {
      _packageNames[packageRoot] = _loadPackageName(packageRoot);
    }
    return _packageNames[packageRoot];
  }

  /// Find package root by looking for pubspec.yaml.
  /// Returns null if not found.
  String? findPackageRoot(String filePath) {
    var dir = Directory(p.dirname(filePath));
    while (dir.path != dir.parent.path) {
      if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
        return dir.path;
      }
      dir = dir.parent;
    }
    return null;
  }

  /// Get repo root for a package, with caching.
  String _getRepoRoot(String packageRoot) {
    if (!_repoRoots.containsKey(packageRoot)) {
      _repoRoots[packageRoot] = _findRepoRoot(packageRoot);
    }
    return _repoRoots[packageRoot]!;
  }

  /// Load all import_guard.yaml files (once per repo root).
  void _ensureRepoLoaded(String repoRoot) {
    if (_configsByRepo.containsKey(repoRoot)) return;

    final configs = <String, ImportGuardConfig>{};
    _scanDirectory(Directory(repoRoot), configs);
    _configsByRepo[repoRoot] = configs;
  }

  /// Find repo root by looking for .git directory.
  String _findRepoRoot(String packageRoot) {
    var dir = Directory(packageRoot);
    while (dir.path != dir.parent.path) {
      if (Directory(p.join(dir.path, '.git')).existsSync()) {
        return dir.path;
      }
      dir = dir.parent;
    }
    return packageRoot; // Fallback to package root if no .git found
  }

  /// Recursively scan directory for import_guard.yaml files.
  void _scanDirectory(Directory dir, Map<String, ImportGuardConfig> configs) {
    if (!dir.existsSync()) return;

    final configFile = File(p.join(dir.path, 'import_guard.yaml'));
    if (configFile.existsSync()) {
      try {
        final content = configFile.readAsStringSync();
        final yaml = loadYaml(content) as YamlMap?;
        if (yaml != null) {
          configs[dir.path] =
              ImportGuardConfig.fromYaml(yaml, dir.path, configFile.path);
        }
      } catch (_) {
        // Ignore invalid yaml files
      }
    }

    // Scan subdirectories
    try {
      for (final entity in dir.listSync()) {
        if (entity is Directory) {
          final name = p.basename(entity.path);
          // Skip hidden directories and common non-source directories
          if (!name.startsWith('.') &&
              name != 'build' &&
              name != 'node_modules') {
            _scanDirectory(entity, configs);
          }
        }
      }
    } catch (_) {
      // Ignore permission errors
    }
  }

  String? _loadPackageName(String packageRoot) {
    final pubspecFile = File(p.join(packageRoot, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) return null;

    try {
      final content = pubspecFile.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap?;
      return yaml?['name'] as String?;
    } catch (_) {
      return null;
    }
  }
}
