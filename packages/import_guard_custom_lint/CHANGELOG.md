# Changelog

## 0.0.3

- Fix: monorepo performance improvement (share config cache across packages)

## 0.0.1

- Initial release
- custom_lint based implementation for Dart 3.6+
- Support for glob patterns (`*`, `**`)
- Hierarchical config inheritance from repo root
- Trie-based O(path_length) pattern matching
