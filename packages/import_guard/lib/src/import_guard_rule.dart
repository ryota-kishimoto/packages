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

  /// Cache for package root lookups to avoid repeated filesystem traversal.
  static final _packageRootCache = <String, String?>{};

  @override
  void visitImportDirective(ImportDirective node) {
    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    final currentUnit = context.currentUnit;
    if (currentUnit == null) return;

    final filePath = currentUnit.file.path;
    final packageRoot = _findPackageRoot(filePath);
    if (packageRoot == null) return;

    final configs = _configCache.getConfigsForFile(filePath, packageRoot);
    if (configs.isEmpty) return;

    final packageName = _configCache.getPackageName(packageRoot);

    for (final config in configs) {
      // Fast path: check absolute patterns using Trie O(path_length)
      if (config.absolutePatternTrie.matches(importUri)) {
        rule.reportAtNode(node, arguments: [importUri, config.configFilePath]);
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
            rule.reportAtNode(node, arguments: [importUri, config.configFilePath]);
            return;
          }
        }
      }
    }
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
