import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'core/core.dart';

/// An analyzer rule that guards imports based on import_guard.yaml configuration.
class ImportGuardRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'import_guard',
    "Import of '{0}' is not allowed by '{1}'.",
  );

  ImportGuardRule()
      : super(
          name: 'import_guard',
          description: 'Guards imports based on import_guard.yaml configuration.',
        );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _ImportGuardVisitor(this, context);
    registry.addImportDirective(this, visitor);
  }
}

class _ImportGuardVisitor extends SimpleAstVisitor<void> {
  _ImportGuardVisitor(this.rule, this.context);

  final ImportGuardRule rule;
  final RuleContext context;
  final _configCache = ConfigCache();

  /// Cache for PatternMatcher instances per config directory.
  static final _matcherCache = <String, PatternMatcher>{};

  /// Cache to prevent duplicate reports (file:line -> reported).
  static final _reportedCache = <String, bool>{};

  @override
  void visitImportDirective(ImportDirective node) {
    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    final currentUnit = context.currentUnit;
    if (currentUnit == null) return;

    final filePath = currentUnit.file.path;
    final fileDir = filePath.substring(0, filePath.lastIndexOf('/'));

    final configs = _configCache.getConfigsForFile(filePath);
    if (configs.isEmpty) return;

    final packageName = _configCache.getPackageName(fileDir);
    final packageRoot = _configCache.getPackageRoot(fileDir);

    for (final config in configs) {
      final matcher = _getOrCreateMatcher(config, packageName, packageRoot);

      // Check if import is denied
      if (_isDenied(importUri, config, matcher, filePath)) {
        _reportOnce(node, filePath, importUri, config.configFilePath);
        return;
      }

      // Check if import is not allowed (when allow list is specified)
      if (config.hasAllowRules &&
          !_isAllowed(importUri, config, matcher, filePath)) {
        _reportOnce(node, filePath, importUri, config.configFilePath);
        return;
      }
    }
  }

  /// Report only once per file:line:importUri to prevent duplicates.
  void _reportOnce(
    ImportDirective node,
    String filePath,
    String importUri,
    String configFilePath,
  ) {
    final key = '$filePath:${node.offset}:$importUri';
    if (_reportedCache.containsKey(key)) return;
    _reportedCache[key] = true;
    rule.reportAtNode(node, arguments: [importUri, configFilePath]);
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
