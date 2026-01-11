# import_guard

[![CI](https://github.com/ryota-kishimoto/import_guard/actions/workflows/ci.yaml/badge.svg)](https://github.com/ryota-kishimoto/import_guard/actions/workflows/ci.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

> Import restriction analyzer for Dart/Flutter projects

Enforce clean architecture layer dependencies with configurable deny/allow rules per folder.

## Packages

| Package | Description | Version |
|---------|-------------|---------|
| [import_guard](packages/import_guard/) | Analyzer plugin (Dart 3.10+) | [![pub package](https://img.shields.io/pub/v/import_guard.svg)](https://pub.dev/packages/import_guard) |
| [import_guard_custom_lint](packages/import_guard_custom_lint/) | custom_lint integration (Dart 3.6+) | [![pub package](https://img.shields.io/pub/v/import_guard_custom_lint.svg)](https://pub.dev/packages/import_guard_custom_lint) |

### Which package should I use?

| Your environment | Recommended |
|------------------|-------------|
| Dart 3.10+ | **import_guard** - Native analyzer plugin, better IDE integration |
| Dart 3.6 - 3.9 | **import_guard_custom_lint** - Works with older Dart versions |
| Using custom_lint ecosystem | **import_guard_custom_lint** |

## Quick Start

### 1. Install

**For Dart 3.10+:**
```yaml
# pubspec.yaml
dev_dependencies:
  import_guard: ^0.0.6
```

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - import_guard
```

**For Dart 3.6+:**
```yaml
# pubspec.yaml
dev_dependencies:
  import_guard_custom_lint: ^0.0.8
  custom_lint: ^0.7.0
```

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - custom_lint
```

### 2. Configure

Create `import_guard.yaml` in any directory:

```yaml
# lib/domain/import_guard.yaml
deny:
  - package:my_app/presentation/**
  - package:my_app/data/**
```

### 3. Run

```bash
# import_guard
dart analyze

# import_guard_custom_lint
dart run custom_lint
```

## Example: Clean Architecture

```
my_app/
├── lib/
│   ├── domain/
│   │   ├── import_guard.yaml  # Deny presentation & data
│   │   └── user.dart
│   ├── presentation/
│   │   ├── import_guard.yaml  # Deny data (can use domain)
│   │   └── user_page.dart
│   └── data/
│       ├── import_guard.yaml  # Can use domain
│       └── user_repository.dart
```

```yaml
# lib/domain/import_guard.yaml
deny:
  - package:my_app/presentation/**
  - package:my_app/data/**

# lib/presentation/import_guard.yaml
deny:
  - package:my_app/data/**

# lib/data/import_guard.yaml
# (no restrictions - can import domain)
```

## Architecture

```
packages/
├── import_guard/              # Analyzer plugin implementation
│   └── lib/src/core/          # Shared core logic
└── import_guard_custom_lint/  # custom_lint implementation
    └── lib/src/core/          # Shared core logic (synced)
```

Both packages share the same core logic for config loading and pattern matching.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT
