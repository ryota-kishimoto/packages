// ignore_for_file: deprecated_member_use

import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart' show ErrorReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:import_guard_core/import_guard_core.dart';

class ImportGuardLint extends DartLintRule {
  ImportGuardLint() : super(code: _code);

  static const _code = LintCode(
    name: 'import_guard',
    problemMessage: 'This import is not allowed: {0}',
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
        // Fast path: check absolute patterns using Trie O(path_length)
        if (config.absolutePatternTrie.matches(importUri)) {
          reporter.atNode(
            node,
            _code,
            arguments: [importUri],
          );
          return;
        }

        // Slow path: check relative patterns O(patterns)
        if (config.relativePatterns.isNotEmpty) {
          final matcher = PatternMatcher(
            configDir: config.configDir,
            packageRoot: packageRoot,
            packageName: packageName,
          );

          for (final pattern in config.relativePatterns) {
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
      }
    });
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
