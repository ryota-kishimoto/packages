# Changelog

## 0.0.4

- Fix: correct SDK constraint to >=3.7.0 (was incorrectly set to ^3.6.0)

## 0.0.3

- Fix: share config cache across packages in monorepo (performance improvement)

## 0.0.2

- Update repository URL
- Simplify README

## 0.0.1

- Initial release
- `PatternTrie` for O(path_length) pattern matching
- `PatternMatcher` for glob pattern support (`*`, `**`)
- `ConfigCache` for cached configuration loading
- `ImportGuardConfig` for deny pattern configuration
