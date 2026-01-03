// This file demonstrates import_guard in action.

// NG - should be flagged by import_guard (dart:mirrors is denied in root import_guard.yaml)
import 'dart:mirrors';

void main() {
  // Use mirrors to avoid unused_import warning
  final mirror = reflectClass(Object);
  print('import_guard example: ${mirror.simpleName}');
}
