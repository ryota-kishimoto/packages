# import_guard

A custom_lint package to guard imports between packages and folders.

[日本語版 README](README.ja.md)

## Features

- Define import restrictions per folder using `import_guard.yaml`
- Glob patterns: `package:my_app/data/**`, `package:flutter/**`
- Works with package imports and relative imports

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

## License

MIT
