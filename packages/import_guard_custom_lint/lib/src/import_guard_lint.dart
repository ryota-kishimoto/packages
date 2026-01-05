// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart' show AstNode, ImportDirective;
import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart' show ErrorReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'core/core.dart';

/// Extension to report errors compatible with both analyzer 6.x and 8.x.
extension ErrorReporterCompat on ErrorReporter {
  /// Reports an error at the given node, using the appropriate API
  /// for the analyzer version.
  void reportLintForNode(LintCode code, AstNode node, List<Object> arguments) {
    // Try analyzer 8.x API first (atNode), fall back to 6.x (reportErrorForNode)
    try {
      // ignore: avoid_dynamic_calls
      (this as dynamic).atNode(node, code, arguments: arguments);
    } on NoSuchMethodError {
      // ignore: avoid_dynamic_calls
      (this as dynamic).reportErrorForNode(code, node, arguments);
    }
  }
}

class ImportGuardLint extends DartLintRule {
  ImportGuardLint() : super(code: _code);

  static const _code = LintCode(
    name: 'import_guard',
    problemMessage: "Import of '{0}' is not allowed by '{1}'.",
    errorSeverity: ErrorSeverity.WARNING,
  );

  final _configCache = ConfigCache();

  /// Cache for PatternMatcher instances per config directory.
  static final _matcherCache = <String, PatternMatcher>{};

  /// Cache to prevent duplicate reports (file:offset:importUri -> reported).
  static final _reportedCache = <String, bool>{};

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final filePath = resolver.source.fullName;
    final fileDir = filePath.substring(0, filePath.lastIndexOf('/'));

    final configs = _configCache.getConfigsForFile(filePath);
    if (configs.isEmpty) return;

    final packageName = _configCache.getPackageName(fileDir);
    final packageRoot = _configCache.getPackageRoot(fileDir);

    context.registry.addImportDirective((node) {
      final importUri = node.uri.stringValue;
      if (importUri == null) return;

      for (final config in configs) {
        final matcher = _getOrCreateMatcher(config, packageName, packageRoot);

        // Check if import is denied
        if (_isDenied(importUri, config, matcher, filePath)) {
          _reportOnce(reporter, node, filePath, importUri, config.configFilePath);
          return;
        }

        // Check if import is not allowed (when allow list is specified)
        if (config.hasAllowRules &&
            !_isAllowed(importUri, config, matcher, filePath)) {
          _reportOnce(reporter, node, filePath, importUri, config.configFilePath);
          return;
        }
      }
    });
  }

  /// Report only once per file:offset:importUri to prevent duplicates.
  void _reportOnce(
    ErrorReporter reporter,
    ImportDirective node,
    String filePath,
    String importUri,
    String configFilePath,
  ) {
    final key = '$filePath:${node.offset}:$importUri';
    if (_reportedCache.containsKey(key)) return;
    _reportedCache[key] = true;
    reporter.reportLintForNode(_code, node, [importUri, configFilePath]);
  }

  /// Get or create a cached PatternMatcher for the given config.
  PatternMatcher _getOrCreateMatcher(
    ImportGuardConfig config,
    String? packageName,
    String? packageRoot,
  ) {
    final cacheKey = config.configDir;
    var matcher = _matcherCache[cacheKey];
    if (matcher == null) {
      matcher = PatternMatcher(
        configDir: config.configDir,
        packageName: packageName,
        packageRoot: packageRoot,
      );
      _matcherCache[cacheKey] = matcher;
    }
    return matcher;
  }

  /// Returns true if the import matches any deny pattern.
  bool _isDenied(
    String importUri,
    ImportGuardConfig config,
    PatternMatcher matcher,
    String filePath,
  ) {
    if (config.denyPatternTrie.matches(importUri)) {
      return true;
    }

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
    if (config.allowPatternTrie.matches(importUri)) {
      return true;
    }

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
}
