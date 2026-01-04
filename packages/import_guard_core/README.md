# import_guard_core

Core logic for import_guard - pattern matching and configuration parsing.

This package is used internally by `import_guard` and `import_guard_custom_lint`.

## Features

- `PatternTrie`: Efficient O(path_length) pattern matching using Trie data structure
- `PatternMatcher`: Glob pattern matching (`*`, `**`) for imports
- `ConfigCache`: Cached configuration loading from `import_guard.yaml` files
- `ImportGuardConfig`: Configuration model with deny patterns

## Usage

```dart
import 'package:import_guard_core/import_guard_core.dart';

// Pattern matching with Trie
final trie = PatternTrie()
  ..insert('package:my_app/data/**')
  ..insert('dart:mirrors');

print(trie.matches('package:my_app/data/repo.dart')); // true
print(trie.matches('dart:mirrors')); // true

// Configuration loading
final configCache = ConfigCache();
final configs = configCache.getConfigsForFile(filePath, packageRoot);
```

## Related Packages

- [import_guard](https://pub.dev/packages/import_guard) - Native analyzer plugin (Dart 3.10+)
- [import_guard_custom_lint](https://pub.dev/packages/import_guard_custom_lint) - custom_lint implementation (Dart 3.6+)
