## 0.1.0

- Initial release
- Define import restrictions per folder using `import_guard.yaml`
- Glob patterns: `**` (all descendants), `*` (direct children only)
- Package imports: `package:my_app/data/**`
- External packages: `package:flutter/**`, `dart:mirrors`
- Configurable severity (error/warning/info) via `analysis_options.yaml`
