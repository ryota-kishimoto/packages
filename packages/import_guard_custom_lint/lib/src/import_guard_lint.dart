// ignore_for_file: deprecated_member_use

import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart' show ErrorReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'core/core.dart';

class ImportGuardLint extends DartLintRule {
  ImportGuardLint() : super(code: _code);

  static const _code = LintCode(
    name: 'import_guard',
    problemMessage: "Import of '{0}' is not allowed by '{1}'.",
    errorSeverity: ErrorSeverity.WARNING,
  );
  final _configCache = ConfigCache();

  /// Cache for package root lookups to avoid repeated filesystem traversal.
  static final _packageRootCache = <String, String?>{};

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

        // Check if import is denied
        if (_isDenied(importUri, config, matcher, filePath)) {
          reporter.atNode(
            node,
            _code,
            arguments: [importUri, config.configFilePath],
          );
          return;
        }

        // Check if import is not allowed (when allow list is specified)
        if (config.hasAllowRules &&
            !_isAllowed(importUri, config, matcher, filePath)) {
          reporter.atNode(
            node,
            _code,
            arguments: [importUri, config.configFilePath],
          );
          return;
        }
      }
    });
  }

  /// Returns true if the import matches any deny pattern.
  bool _isDenied(
    String importUri,
    ImportGuardConfig config,
    PatternMatcher matcher,
    String filePath,
  ) {
    // Fast path: check absolute patterns using Trie
    if (config.denyPatternTrie.matches(importUri)) {
      return true;
    }

    // Slow path: check relative patterns
    for (final pattern in config.denyRelativePatterns) {
      if (matcher.matches(
        importUri: importUri,
        pattern: pattern,
        filePath: filePath,
      )) {
        return true;
      }
    }

    return false;
  }

  /// Returns true if the import matches any allow pattern.
  bool _isAllowed(
    String importUri,
    ImportGuardConfig config,
    PatternMatcher matcher,
    String filePath,
  ) {
    // Fast path: check absolute patterns using Trie
    if (config.allowPatternTrie.matches(importUri)) {
      return true;
    }

    // Slow path: check relative patterns
    for (final pattern in config.allowRelativePatterns) {
      if (matcher.matches(
        importUri: importUri,
        pattern: pattern,
        filePath: filePath,
      )) {
        return true;
      }
    }

    return false;
  }

  String? _findPackageRoot(String filePath) {
    // Check cache first
    if (_packageRootCache.containsKey(filePath)) {
      return _packageRootCache[filePath];
    }

    final result = _configCache.findPackageRoot(filePath);
    _packageRootCache[filePath] = result;
    return result;
  }
}
