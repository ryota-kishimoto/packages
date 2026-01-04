// NG: dart:mirrors is denied in root import_guard.yaml
// expect_lint: import_guard
import 'dart:mirrors';

void main() {
  final mirror = reflectClass(Object);
  print('import_guard example: ${mirror.simpleName}');
}
