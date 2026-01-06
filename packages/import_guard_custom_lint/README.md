# import_guard_custom_lint

A custom_lint package to guard imports between packages and folders.

[日本語版 README](README.ja.md)

> **Note**: For Dart 3.10+, consider using [import_guard](https://pub.dev/packages/import_guard) which uses the native analyzer plugin API with better IDE integration.

## Features

- Define import restrictions per folder using `import_guard.yaml`
- Glob patterns: `package:my_app/data/**`, `package:flutter/**`
- Works with package imports and relative imports
- Hierarchical config inheritance from repo root
- Allow list support for exceptions

## Installation

```yaml
dev_dependencies:
  import_guard_custom_lint: ^0.0.7
  custom_lint: ^0.7.0
```

Enable in `analysis_options.yaml`:

```yaml
analyzer:
  plugins:
    - custom_lint
```

## Usage

Create `import_guard.yaml` in any directory to define restrictions for files in that directory.

### Configuration Options

```yaml
# Deny specific imports (files in this directory cannot import these)
deny:
  - package:my_app/presentation/**
  - package:my_app/data/**
  - dart:mirrors

# Allow specific imports (exceptions to deny rules, or whitelist mode)
allow:
  - package:my_app/domain/**
  - dart:core

# Inherit rules from parent directories (default: true)
inherit: true
```

### Example: Clean Architecture

For a Flutter app named `my_app`:

```
my_app/
├── pubspec.yaml          # name: my_app
├── import_guard.yaml     # Root-level rules (apply to entire project)
└── lib/
    ├── domain/
    │   ├── import_guard.yaml  # Domain-specific rules
    │   └── user.dart
    ├── presentation/
    │   └── user_page.dart
    └── data/
        └── user_repository.dart
```

Root-level config:
```yaml
# import_guard.yaml
deny:
  - dart:mirrors  # Deny in entire project
```

Domain layer config:
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
dart run custom_lint
```

## Related Packages

- [import_guard](https://pub.dev/packages/import_guard) - Native analyzer plugin (Dart 3.10+)

## License

MIT
