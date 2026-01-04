# import_guard

A custom_lint package to guard imports between packages and folders.

[日本語版 README](README.ja.md)

## Features

- Define import restrictions per folder using `import_guard.yaml`
- Support glob patterns: `package:foo`, `package:foo/*`, `package:foo/**`
- Support relative path patterns: `../presenter/**`, `./internal/*`
- Works with both relative imports and package imports

## Installation

Add to your `pubspec.yaml`:

```yaml
dev_dependencies:
  import_guard:
    git:
      url: https://github.com/ryota-kishimoto/packages
      path: packages/import_guard
  custom_lint: ^0.8.0
```

Enable in `analysis_options.yaml`:

```yaml
analyzer:
  plugins:
    - custom_lint
```

### Configure Severity (Optional)

By default, violations are reported as errors. You can change the severity to `warning` or `info`:

```yaml
# analysis_options.yaml
custom_lint:
  rules:
    - import_guard:
      severity: warning  # error (default), warning, or info
```

Note: `severity` must be at the same indentation level as `import_guard:`, not nested under it.

## Usage

Create `import_guard.yaml` in any directory to define restrictions for files in that directory.

### Example: Clean Architecture

```
lib/
├── domain/
│   ├── import_guard.yaml    # Restrict imports from presenter/infrastructure
│   └── user.dart
├── presenter/
│   └── user_widget.dart
└── infrastructure/
    └── user_repository.dart
```

```yaml
# lib/domain/import_guard.yaml
deny:
  - ../presenter/**
  - ../infrastructure/**
```

This prevents domain layer from importing presenter or infrastructure layers.

### Pattern Types

| Pattern | Matches |
|---------|---------|
| `package:foo` | `package:foo`, `package:foo/bar` |
| `package:foo/*` | `package:foo/bar` (direct children only) |
| `package:foo/**` | `package:foo/bar/baz` (all descendants) |
| `../presenter/**` | All files under sibling `presenter/` directory |
| `dart:mirrors` | Specific dart library |

### Recommended: Use package imports only

To avoid managing both relative and package import patterns, we recommend enabling `always_use_package_imports` lint rule:

```yaml
# analysis_options.yaml
linter:
  rules:
    - always_use_package_imports
```

This ensures all imports use the `package:` format, simplifying your `import_guard.yaml` configuration.

## Running

```bash
dart run custom_lint
```

## License

MIT
