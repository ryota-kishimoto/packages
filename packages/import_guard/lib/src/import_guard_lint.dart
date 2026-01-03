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

  /// Load all import_guard.yaml files from the file's directory up to package root.
  /// Configs closer to the file take precedence.
  static List<ImportGuardConfig> loadAllConfigs(
    String filePath,
    String packageRoot,
  ) {
    final configs = <ImportGuardConfig>[];
    var dir = Directory(p.dirname(filePath));

    while (dir.path.startsWith(packageRoot) || dir.path == packageRoot) {
      final configFile = File(p.join(dir.path, 'import_guard.yaml'));
      if (configFile.existsSync()) {
        final content = configFile.readAsStringSync();
        final yaml = loadYaml(content) as YamlMap?;
        if (yaml != null) {
          configs.add(ImportGuardConfig.fromYaml(yaml, dir.path));
        }
      }

      if (dir.path == packageRoot) break;
      dir = dir.parent;
    }

    return configs;
  }
}

class ImportGuardLint extends DartLintRule {
  ImportGuardLint() : super(code: _code);

  static const _code = LintCode(
    name: 'import_guard',
    problemMessage: 'This import is not allowed: {0}',
    errorSeverity: ErrorSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final filePath = resolver.source.fullName;
    final packageRoot = _findPackageRoot(filePath);
    if (packageRoot == null) return;

    final configs = ImportGuardConfig.loadAllConfigs(filePath, packageRoot);
    if (configs.isEmpty) return;

    // Get package name from pubspec.yaml
    final packageName = _getPackageName(packageRoot);

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
            return; // Only report once per import
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

  String? _getPackageName(String packageRoot) {
    final pubspecFile = File(p.join(packageRoot, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) return null;

    final content = pubspecFile.readAsStringSync();
    final yaml = loadYaml(content) as YamlMap?;
    return yaml?['name'] as String?;
  }

  bool _matchesPattern({
    required String importUri,
    required String pattern,
    required String configDir,
    required String filePath,
    required String packageRoot,
    required String? packageName,
  }) {
    // Handle relative patterns (starting with ./ or ../)
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

    // Handle absolute patterns (package:foo, dart:foo)
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
    // Resolve the pattern to an absolute path from configDir
    final resolvedPatternPath = p.normalize(p.join(configDir, pattern));

    // Handle relative imports (import '../foo.dart')
    if (importUri.startsWith('.')) {
      final fileDir = p.dirname(filePath);
      final resolvedImportPath = p.normalize(p.join(fileDir, importUri));
      return _pathMatchesPattern(resolvedImportPath, resolvedPatternPath);
    }

    // Handle package imports (import 'package:myapp/foo.dart')
    if (packageName != null && importUri.startsWith('package:$packageName/')) {
      // Convert package import to file path
      final importPath = importUri.substring('package:$packageName/'.length);
      final absoluteImportPath = p.join(packageRoot, 'lib', importPath);
      return _pathMatchesPattern(absoluteImportPath, resolvedPatternPath);
    }

    return false;
  }

  bool _pathMatchesPattern(String path, String pattern) {
    // Remove glob suffix for matching
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
      // Match anything under this path
      return path.startsWith(patternBase);
    }

    if (matchChildren) {
      // Match only direct children
      if (!path.startsWith('$patternBase${p.separator}')) return false;
      final remainder = path.substring(patternBase.length + 1);
      return !remainder.contains(p.separator);
    }

    // Exact match or file within directory
    return path == patternBase || path.startsWith('$patternBase${p.separator}');
  }

  bool _matchesAbsolutePattern(String importUri, String pattern) {
    // Handle glob-like patterns
    // package:foo/** -> matches package:foo/anything
    // package:foo/* -> matches package:foo/single_segment
    // package:foo -> exact match or prefix match

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

    // Exact match or prefix match (package:foo matches package:foo/bar)
    return importUri == pattern || importUri.startsWith('$pattern/');
  }
}
