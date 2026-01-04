// ignore_for_file: deprecated_member_use
library import_guard;

import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:import_guard/src/import_guard_lint.dart';

PluginBase createPlugin() => _ImportGuardPlugin();

class _ImportGuardPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) {
    final ruleConfig = configs.rules['import_guard'];
    final severity = _parseSeverity(ruleConfig?.json['severity'] as String?);

    return [
      ImportGuardLint(severity: severity),
    ];
  }

  ErrorSeverity _parseSeverity(String? value) {
    switch (value?.toLowerCase()) {
      case 'warning':
        return ErrorSeverity.WARNING;
      case 'info':
        return ErrorSeverity.INFO;
      case 'error':
      default:
        return ErrorSeverity.ERROR;
    }
  }
}
