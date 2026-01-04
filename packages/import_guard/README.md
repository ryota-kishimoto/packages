# import_guard

An analyzer plugin to guard imports between packages and folders.

[日本語版 README](README.ja.md)

> **Requires Dart 3.10+**. For older Dart versions, use [import_guard_custom_lint](https://pub.dev/packages/import_guard_custom_lint).

## Features

- Define import restrictions per folder using `import_guard.yaml`
- Glob patterns: `package:my_app/data/**`, `package:flutter/**`
- Works with package imports and relative imports
- Hierarchical config inheritance from repo root
- Native IDE integration via `dart analyze` / `flutter analyze`

## Installation

```yaml
dependencies:
  import_guard: ^1.0.0
```

Enable in `analysis_options.yaml`:

```yaml
plugins:
  import_guard: ^1.0.0
```

## Usage

Create `import_guard.yaml` in any directory to define restrictions for files in that directory.

### Example: Clean Architecture

For a Flutter app named `my_app`:

```
my_app/
├── pubspec.yaml          # name: my_app
└── lib/
    ├── domain/
    │   ├── import_guard.yaml
    │   └── user.dart
    ├── presentation/
    │   └── user_page.dart
    └── data/
        └── user_repository.dart
```

```yaml
# lib/domain/import_guard.yaml
deny:
  - package:my_app/presentation/**
  - package:my_app/data/**
```

This prevents domain layer from importing presentation or data layers.

### Pattern Types

| Pattern | Matches |
|---------|---------|
| `package:my_app/data/**` | All files under `lib/data/` |
| `package:my_app/data/*` | Direct children of `lib/data/` only |
| `package:flutter/**` | All flutter imports |
| `dart:mirrors` | Specific dart library |
| `../data/**` | Relative path patterns |

### Recommended: Use package imports

To simplify configuration, enable `always_use_package_imports`:

```yaml
# analysis_options.yaml
linter:
  rules:
    - always_use_package_imports
```

Then you only need to write package patterns (no relative path patterns needed).

## Running

```bash
dart analyze
# or
flutter analyze
```

## Related Packages

- [import_guard_custom_lint](https://pub.dev/packages/import_guard_custom_lint) - custom_lint implementation (Dart 3.6+)
- [import_guard_core](https://pub.dev/packages/import_guard_core) - Core logic

## License

MIT
