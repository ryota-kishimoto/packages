import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/import_guard_rule.dart';

/// The entry point for the import_guard analyzer plugin.
Plugin get plugin => ImportGuardPlugin();

class ImportGuardPlugin extends Plugin {
  @override
  String get name => 'import_guard';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(ImportGuardRule());
  }
}
