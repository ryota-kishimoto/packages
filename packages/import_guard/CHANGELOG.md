# Changelog

## 0.0.7

- Add developer documentation (CLAUDE.md, version_compatibility.md)

## 0.0.6

- Fix: remove report cache that prevented re-analysis
- Add multi-level caching for improved performance

## 0.0.5

- Fix: prevent duplicate warning reports

## 0.0.4

- Fix: lower SDK constraint to ^3.9.0 (was ^3.10.0)
- Fix: add WARNING severity to LintCode to match registerWarningRule()

## 0.0.3

- Fix: monorepo performance improvement (share config cache across packages)

## 0.0.1

- Initial release
- Native analyzer plugin using analysis_server_plugin (Dart 3.9+)
- Full IDE integration with `dart analyze` and `flutter analyze`
- Support for glob patterns (`*`, `**`)
- Hierarchical config inheritance from repo root
- Trie-based O(path_length) pattern matching
