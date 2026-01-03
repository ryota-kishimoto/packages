import 'dart:io';

import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart' show ErrorReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

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

  /// Get all applicable configs for a file path.
  /// Returns configs from file's directory up to package root.
  List<ImportGuardConfig> getConfigsForFile(String filePath, String packageRoot) {
    _ensureLoaded(packageRoot);

    final configs = <ImportGuardConfig>[];
    final allConfigs = _cache[packageRoot] ?? {};

    var dir = p.dirname(filePath);
    while (dir.startsWith(packageRoot) || dir == packageRoot) {
      final config = allConfigs[dir];
      if (config != null) {
        configs.add(config);
      }
      if (dir == packageRoot) break;
      dir = p.dirname(dir);
    }

    return configs;
  }

  /// Get cached package name.
  String? getPackageName(String packageRoot) {
    _ensureLoaded(packageRoot);
    return _packageNames[packageRoot];
  }

  /// Load all import_guard.yaml files in the package root (once).
  void _ensureLoaded(String packageRoot) {
    if (_cache.containsKey(packageRoot)) return;

    final configs = <String, ImportGuardConfig>{};
    _scanDirectory(Directory(packageRoot), configs);
    _cache[packageRoot] = configs;

    // Cache package name
    _packageNames[packageRoot] = _loadPackageName(packageRoot);
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
  ImportGuardLint() : super(code: _code);

  static const _code = LintCode(
    name: 'import_guard',
    problemMessage: 'This import is not allowed: {0}',
    errorSeverity: ErrorSeverity.ERROR,
  );

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
        for (final pattern in config.deny) {
          if (_matchesPattern(
            importUri: importUri,
            pattern: pattern,
            configDir: config.configDir,
            filePath: filePath,
            packageRoot: packageRoot,
            packageName: packageName,
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

  bool _matchesPattern({
    required String importUri,
    required String pattern,
    required String configDir,
    required String filePath,
    required String packageRoot,
    required String? packageName,
  }) {
    if (pattern.startsWith('./') || pattern.startsWith('../')) {
      return _matchesRelativePattern(
        importUri: importUri,
        pattern: pattern,
        configDir: configDir,
        filePath: filePath,
        packageRoot: packageRoot,
        packageName: packageName,
      );
    }
    return _matchesAbsolutePattern(importUri, pattern);
  }

  bool _matchesRelativePattern({
    required String importUri,
    required String pattern,
    required String configDir,
    required String filePath,
    required String packageRoot,
    required String? packageName,
  }) {
    final resolvedPatternPath = p.normalize(p.join(configDir, pattern));

    if (importUri.startsWith('.')) {
      final fileDir = p.dirname(filePath);
      final resolvedImportPath = p.normalize(p.join(fileDir, importUri));
      return _pathMatchesPattern(resolvedImportPath, resolvedPatternPath);
    }

    if (packageName != null && importUri.startsWith('package:$packageName/')) {
      final importPath = importUri.substring('package:$packageName/'.length);
      final absoluteImportPath = p.join(packageRoot, 'lib', importPath);
      return _pathMatchesPattern(absoluteImportPath, resolvedPatternPath);
    }

    return false;
  }

  bool _pathMatchesPattern(String path, String pattern) {
    String patternBase = pattern;
    bool matchChildren = false;
    bool matchAll = false;

    if (pattern.endsWith('/**')) {
      patternBase = pattern.substring(0, pattern.length - 3);
      matchAll = true;
    } else if (pattern.endsWith('/*')) {
      patternBase = pattern.substring(0, pattern.length - 2);
      matchChildren = true;
    }

    patternBase = p.normalize(patternBase);

    if (matchAll) {
      return path.startsWith(patternBase);
    }

    if (matchChildren) {
      if (!path.startsWith('$patternBase${p.separator}')) return false;
      final remainder = path.substring(patternBase.length + 1);
      return !remainder.contains(p.separator);
    }

    return path == patternBase || path.startsWith('$patternBase${p.separator}');
  }

  bool _matchesAbsolutePattern(String importUri, String pattern) {
    if (pattern.endsWith('/**')) {
      final prefix = pattern.substring(0, pattern.length - 3);
      return importUri.startsWith(prefix);
    }

    if (pattern.endsWith('/*')) {
      final prefix = pattern.substring(0, pattern.length - 2);
      if (!importUri.startsWith('$prefix/')) return false;
      final remainder = importUri.substring(prefix.length + 1);
      return !remainder.contains('/');
    }

    return importUri == pattern || importUri.startsWith('$pattern/');
  }
}
