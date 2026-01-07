# Version Compatibility

## custom_lint versions

| custom_lint | IDE Support | CLI Support | Notes |
|-------------|-------------|-------------|-------|
| ^0.7.0 | ✅ | ✅ | **Recommended** |
| ^0.8.0 | ❌ | ✅ | CLI only, IDE doesn't show warnings |

## Why not custom_lint 0.8.x?

custom_lint 0.8.x works with `dart run custom_lint` but **does not show warnings in IDE** (VS Code, Android Studio, IntelliJ).

If you need real-time feedback in your editor, use 0.7.x.

## analyzer version

This package supports analyzer 6.x to 8.x:

```yaml
dependencies:
  analyzer: ">=6.0.0 <9.0.0"
  custom_lint_builder: ">=0.6.2 <0.8.0"
```

The analyzer version is managed by custom_lint_builder transitively. You typically don't need to specify it directly.

## Monorepo considerations

If you have version conflicts in a monorepo:

1. Ensure all packages use the same custom_lint version
2. Use `flutter pub get` consistently (don't mix with `dart pub get`)
3. Pin exact versions if needed

See [dart-lang/sdk#48925](https://github.com/dart-lang/sdk/issues/48925) for details on monorepo plugin issues.

## SDK compatibility

| SDK | Status |
|-----|--------|
| ^3.4.0 | ✅ Supported |
| <3.4.0 | ❌ Not supported |

The SDK constraint is `^3.4.0` to support analyzer 6.x+.
