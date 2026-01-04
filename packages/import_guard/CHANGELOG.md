# Changelog

## 0.0.3

- Fix: monorepo performance improvement (share config cache across packages)

## 0.0.1

- Initial release
- Native analyzer plugin using analysis_server_plugin (Dart 3.10+)
- Full IDE integration with `dart analyze` and `flutter analyze`
- Support for glob patterns (`*`, `**`)
- Hierarchical config inheritance from repo root
- Trie-based O(path_length) pattern matching
