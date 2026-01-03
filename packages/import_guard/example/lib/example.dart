// NG: dart:mirrors is denied in root import_guard.yaml
import 'dart:mirrors';

void main() {
  final mirror = reflectClass(Object);
  print('import_guard example: ${mirror.simpleName}');
}
