/// Example file demonstrating import_guard rules.
///
/// This file is in the root lib/ directory.
/// Rules applied: example/import_guard.yaml
///
/// ```yaml
/// # example/import_guard.yaml
/// deny:
///   - dart:mirrors  # Denied in entire project
/// ```

// NG: dart:mirrors is denied in root import_guard.yaml
import 'dart:mirrors';

import 'package:import_guard_example/domain/user.dart';

void main() {
  // Using dart:mirrors (which is denied)
  final mirror = reflectClass(User);
  print('import_guard example');
  print('Class name: ${mirror.simpleName}');
}
