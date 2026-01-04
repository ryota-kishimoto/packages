// ignore_for_file: deprecated_member_use
// TODO: Migrate to DiagnosticSeverity/DiagnosticReporter when custom_lint_builder supports it
import 'dart:io';

import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart' show ErrorReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'pattern_matcher.dart';

/// Configuration for import_guard loaded from import_guard.yaml
class ImportGuardConfig {
  final List<String> deny;
  final String configDir;

  ImportGuardConfig({required this.deny, required this.configDir});

  factory ImportGuardConfig.fromYaml(YamlMap yaml, String configDir) {
    final denyList = yaml['deny'] as YamlList?;
    return ImportGuardConfig(
      deny: denyList?.map((e) => e.toString()).toList() ?? [],
      configDir: configDir,
    );
  }
}

/// Cache for import_guard.yaml configurations.
/// Scans all configs once per package root for better performance.
class ConfigCache {
  static final _instance = ConfigCache._();
  factory ConfigCache() => _instance;
  ConfigCache._();

  /// Map: packageRoot -> (Map: configDir -> config)
  final _cache = <String, Map<String, ImportGuardConfig>>{};

  /// Map: packageRoot -> packageName
  final _packageNames = <String, String?>{};

  /// Map: packageRoot -> repoRoot
  final _repoRoots = <String, String>{};

  /// Get all applicable configs for a file path.
  /// Returns configs from file's directory up to repo root.
  List<ImportGuardConfig> getConfigsForFile(String filePath, String packageRoot) {
    _ensureLoaded(packageRoot);

    final configs = <ImportGuardConfig>[];
    final allConfigs = _cache[packageRoot] ?? {};
    final repoRoot = _repoRoots[packageRoot] ?? packageRoot;

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
    _ensureLoaded(packageRoot);
    return _packageNames[packageRoot];
  }

  /// Load all import_guard.yaml files (once per package root).
  void _ensureLoaded(String packageRoot) {
    if (_cache.containsKey(packageRoot)) return;

    final repoRoot = _findRepoRoot(packageRoot);
    _repoRoots[packageRoot] = repoRoot;

    final configs = <String, ImportGuardConfig>{};

    // Scan from repo root (includes package root and ancestors)
    _scanDirectory(Directory(repoRoot), configs);

    _cache[packageRoot] = configs;
    _packageNames[packageRoot] = _loadPackageName(packageRoot);
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
          configs[dir.path] = ImportGuardConfig.fromYaml(yaml, dir.path);
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

class ImportGuardLint extends DartLintRule {
  ImportGuardLint({ErrorSeverity severity = ErrorSeverity.ERROR})
      : _code = LintCode(
          name: 'import_guard',
          problemMessage: 'This import is not allowed: {0}',
          errorSeverity: severity,
        ),
        super(
          code: LintCode(
            name: 'import_guard',
            problemMessage: 'This import is not allowed: {0}',
            errorSeverity: severity,
          ),
        );

  final LintCode _code;

  final _configCache = ConfigCache();

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final filePath = resolver.source.fullName;
    final packageRoot = _findPackageRoot(filePath);
    if (packageRoot == null) return;

    final configs = _configCache.getConfigsForFile(filePath, packageRoot);
    if (configs.isEmpty) return;

    final packageName = _configCache.getPackageName(packageRoot);

    context.registry.addImportDirective((node) {
      final importUri = node.uri.stringValue;
      if (importUri == null) return;

      for (final config in configs) {
        final matcher = PatternMatcher(
          configDir: config.configDir,
          packageRoot: packageRoot,
          packageName: packageName,
        );

        for (final pattern in config.deny) {
          if (matcher.matches(
            importUri: importUri,
            pattern: pattern,
            filePath: filePath,
          )) {
            reporter.atNode(
              node,
              _code,
              arguments: [importUri],
            );
            return;
          }
        }
      }
    });
  }

  String? _findPackageRoot(String filePath) {
    var dir = Directory(p.dirname(filePath));
    while (dir.path != dir.parent.path) {
      if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
        return dir.path;
      }
      dir = dir.parent;
    }
    return null;
  }
}
