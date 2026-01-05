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

  /// Cached repo root (found once, reused forever).
  String? _repoRoot;

  /// All configs in the repo, keyed by directory path.
  Map<String, ImportGuardConfig>? _allConfigs;

  /// Cache: directory path -> list of applicable configs.
  final _configsForDirCache = <String, List<ImportGuardConfig>>{};

  /// Cache: directory path -> package name.
  final _packageNameCache = <String, String?>{};

  /// Get all applicable configs for a file path.
  /// Returns configs from file's directory up to repo root.
  /// Stops traversing if a config has `inherit: false`.
  List<ImportGuardConfig> getConfigsForFile(String filePath) {
    // Use lastIndexOf instead of p.dirname for speed (14ms -> 1ms per 10k calls)
    final lastSlash = filePath.lastIndexOf('/');
    final dir = lastSlash > 0 ? filePath.substring(0, lastSlash) : filePath;

    // Check directory cache first (O(1) lookup)
    final cached = _configsForDirCache[dir];
    if (cached != null) return cached;

    // Ensure repo is loaded
    _ensureLoaded(dir);

    final configs = <ImportGuardConfig>[];
    final allConfigs = _allConfigs!;
    final repoRoot = _repoRoot!;

    var currentDir = dir;
    while (true) {
      final config = allConfigs[currentDir];
      if (config != null) {
        configs.add(config);
        if (!config.inherit) break;
      }
      if (currentDir == repoRoot || currentDir == p.dirname(currentDir)) break;
      currentDir = p.dirname(currentDir);
    }

    _configsForDirCache[dir] = configs;
    return configs;
  }

  /// Reset all caches. Only for testing.
  void reset() {
    _repoRoot = null;
    _allConfigs = null;
    _configsForDirCache.clear();
    _packageNameCache.clear();
    _packageRootCache.clear();
  }

  /// Cache: directory path -> package root.
  final _packageRootCache = <String, String?>{};

  /// Get package name for directory (cached).
  String? getPackageName(String dir) {
    if (_packageNameCache.containsKey(dir)) {
      return _packageNameCache[dir];
    }

    final packageRoot = getPackageRoot(dir);
    if (packageRoot == null) {
      _packageNameCache[dir] = null;
      return null;
    }

    if (_packageNameCache.containsKey(packageRoot)) {
      final name = _packageNameCache[packageRoot];
      _packageNameCache[dir] = name;
      return name;
    }

    final name = _loadPackageName(packageRoot);
    _packageNameCache[packageRoot] = name;
    _packageNameCache[dir] = name;
    return name;
  }

  /// Get package root for directory (cached).
  String? getPackageRoot(String dir) {
    if (_packageRootCache.containsKey(dir)) {
      return _packageRootCache[dir];
    }

    final packageRoot = _findPackageRoot(dir);
    _packageRootCache[dir] = packageRoot;

    // Also cache for the packageRoot itself
    if (packageRoot != null) {
      _packageRootCache[packageRoot] = packageRoot;
    }
    return packageRoot;
  }

  /// Ensure repo is loaded. Only does I/O once.
  void _ensureLoaded(String startDir) {
    if (_allConfigs != null) return;

    _repoRoot = _findRepoRoot(startDir);
    _allConfigs = {};
    _scanDirectory(Directory(_repoRoot!), _allConfigs!);
  }

  /// Find package root by looking for pubspec.yaml (used as root for config scanning).
  String _findRepoRoot(String startDir) {
    var dir = Directory(startDir);
    while (dir.path != dir.parent.path) {
      if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
        return dir.path;
      }
      dir = dir.parent;
    }
    return startDir; // Fallback if no pubspec.yaml found
  }

  /// Find package root by looking for pubspec.yaml.
  String? _findPackageRoot(String startDir) {
    var dir = Directory(startDir);
    final repoRoot = _repoRoot;
    while (dir.path != dir.parent.path) {
      if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
        return dir.path;
      }
      // Don't go above repo root
      if (repoRoot != null && dir.path == repoRoot) break;
      dir = dir.parent;
    }
    return null;
  }

  /// Recursively scan directory for import_guard.yaml/.yml files.
  void _scanDirectory(Directory dir, Map<String, ImportGuardConfig> configs) {
    if (!dir.existsSync()) return;

    // Try .yaml first, then .yml
    var configFile = File(p.join(dir.path, 'import_guard.yaml'));
    if (!configFile.existsSync()) {
      configFile = File(p.join(dir.path, 'import_guard.yml'));
    }
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

    try {
      for (final entity in dir.listSync()) {
        if (entity is Directory) {
          final name = p.basename(entity.path);
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
