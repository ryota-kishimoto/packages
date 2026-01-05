import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'pattern_trie.dart';

/// Configuration for import_guard loaded from import_guard.yaml
class ImportGuardConfig {
  final List<String> deny;
  final String configDir;

  /// Path to the import_guard.yaml file that defined this config.
  final String configFilePath;

  /// Pre-built Trie for absolute patterns (package:, dart:)
  final PatternTrie absolutePatternTrie;

  /// Relative patterns that need context-aware matching
  final List<String> relativePatterns;

  ImportGuardConfig._({
    required this.deny,
    required this.configDir,
    required this.configFilePath,
    required this.absolutePatternTrie,
    required this.relativePatterns,
  });

  factory ImportGuardConfig.fromYaml(
    YamlMap yaml,
    String configDir,
    String configFilePath,
  ) {
    final denyList = yaml['deny'] as YamlList?;
    final patterns = denyList?.map((e) => e.toString()).toList() ?? [];

    // Separate absolute and relative patterns
    final absolutePatterns = <String>[];
    final relativePatterns = <String>[];

    for (final pattern in patterns) {
      if (pattern.startsWith('./') || pattern.startsWith('../')) {
        relativePatterns.add(pattern);
      } else {
        absolutePatterns.add(pattern);
      }
    }

    // Build Trie from absolute patterns
    final trie = PatternTrie();
    for (final pattern in absolutePatterns) {
      trie.insert(pattern);
    }

    return ImportGuardConfig._(
      deny: patterns,
      configDir: configDir,
      configFilePath: configFilePath,
      absolutePatternTrie: trie,
      relativePatterns: relativePatterns,
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
