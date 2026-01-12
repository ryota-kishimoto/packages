# Changelog

## 1.0.0

- Stable release
- Sync test thresholds with import_guard package

## 0.0.8

- Update SDK constraint from ^3.4.0 to ^3.6.0
- Update analyzer constraint from >=6.0.0 to >=7.0.0
- Update custom_lint_builder constraint from >=0.6.2 <0.8.0 to >=0.7.5 <0.9.0
- Add comprehensive version compatibility documentation
- All custom_lint versions 0.7.5-0.8.1 now work with IDE

## 0.0.7

- Cap custom_lint_builder at <0.8.0 for IDE compatibility
- Update SDK constraint to ^3.4.0
- Simplify dependencies (let custom_lint_builder manage analyzer versions)
- Improve example documentation with inline yaml comments

## 0.0.6

- Add allow list support
- Add multi-level caching for improved performance

## 0.0.5

- Fix duplicate warning reports
- Remove report cache that prevented re-analysis

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
