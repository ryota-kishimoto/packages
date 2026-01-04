import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/import_guard_lint.dart';

/// Entry point for custom_lint plugin.
PluginBase createPlugin() => _ImportGuardPlugin();

class _ImportGuardPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) {
    return [ImportGuardLint()];
  }
}
