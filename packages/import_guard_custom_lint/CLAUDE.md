# import_guard_custom_lint

custom_lint based implementation for import guarding.

## Architecture

```
lib/
├── import_guard_custom_lint.dart  # Entry point (createPlugin)
└── src/
    ├── import_guard_lint.dart     # LintRule implementation
    └── core/
        ├── config.dart            # YAML config loading & caching
        ├── pattern_matcher.dart   # Glob pattern matching
        └── pattern_trie.dart      # Trie for O(n) pattern lookup
```

## Key Design Decisions

### Caching Strategy

- `ConfigCache`: Singleton that scans all `import_guard.yaml` files once per repo
- `_matcherCache`: Static cache for PatternMatcher instances
- Performance: 10,000 calls in ~13ms

### Pattern Matching

- Absolute patterns (`package:`, `dart:`) use Trie for O(path_length) matching
- Relative patterns (`./`, `../`) require context-aware resolution

## Development

### Run tests

```bash
dart test
```

### Test in IDE

Use example/ directory or link from another project:

```yaml
# In test project's pubspec.yaml
dev_dependencies:
  import_guard_custom_lint:
    path: /path/to/import_guard/packages/import_guard_custom_lint
  custom_lint: ^0.7.0
```

### Run CLI

```bash
dart run custom_lint
```

## Version Compatibility

See [doc/version_compatibility.md](doc/version_compatibility.md) for details.

**TL;DR**: Use `custom_lint: ^0.7.0` for IDE support. 0.8.x is CLI only.

## Common Issues

### IDE not showing warnings

1. Check custom_lint version (must be 0.7.x)
2. Restart Dart Analysis Server
3. Check `analysis_options.yaml` has `custom_lint` in plugins

### Duplicate warnings in monorepo

This is a known issue with custom_lint in monorepos. Ensure all packages use the same custom_lint version.

## Related

- [import_guard](../import_guard/) - analysis_server_plugin version (Dart 3.10+)
- Shared core logic is in `src/core/` (synced between packages)
