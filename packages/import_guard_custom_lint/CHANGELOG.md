# Changelog

## 0.0.4

- Fix: correct SDK constraint to >=3.7.0 (analyzer ^8.0.0 requires 3.7.0+)

## 0.0.3

- Fix: monorepo performance improvement (share config cache across packages)

## 0.0.1

- Initial release
- custom_lint based implementation for Dart 3.7+
- Support for glob patterns (`*`, `**`)
- Hierarchical config inheritance from repo root
- Trie-based O(path_length) pattern matching
