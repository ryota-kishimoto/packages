# import_guard

パッケージやフォルダ間のimportを制限するcustom_lintパッケージ。

## 特徴

- `import_guard.yaml`でフォルダごとにimport制限を定義
- globパターン対応: `package:foo`, `package:foo/*`, `package:foo/**`
- 相対パスパターン対応: `../presenter/**`, `./internal/*`
- 相対importとpackage import両方に対応

## インストール

`pubspec.yaml`に追加:

```yaml
dev_dependencies:
  import_guard:
    git:
      url: https://github.com/ryota-kishimoto/packages
      path: packages/import_guard
  custom_lint: ^0.8.0
```

`analysis_options.yaml`で有効化:

```yaml
analyzer:
  plugins:
    - custom_lint
```

### 重大度の設定（オプション）

デフォルトでは違反はエラーとして報告されます。`warning`や`info`に変更可能:

```yaml
# analysis_options.yaml
custom_lint:
  rules:
    - import_guard:
      severity: warning  # error（デフォルト）, warning, info
```

注意: `severity`は`import_guard:`と同じインデントレベルに配置する必要があります（ネストしない）。

## 使い方

任意のディレクトリに`import_guard.yaml`を作成し、そのディレクトリ内のファイルに対するimport制限を定義。

### 例: クリーンアーキテクチャ

```
lib/
├── domain/
│   ├── import_guard.yaml    # presenter/infrastructureからのimportを禁止
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

これでdomainレイヤーがpresenterやinfrastructureレイヤーをimportすることを防げる。

### パターンの種類

| パターン | マッチ対象 |
|---------|-----------|
| `package:foo` | `package:foo`, `package:foo/bar` |
| `package:foo/*` | `package:foo/bar` (直下のみ) |
| `package:foo/**` | `package:foo/bar/baz` (配下全て) |
| `../presenter/**` | 兄弟ディレクトリ`presenter/`配下の全ファイル |
| `dart:mirrors` | 特定のdartライブラリ |

### 推奨: package importのみを使用

相対importとpackage importの両方を管理する手間を省くため、`always_use_package_imports`ルールの有効化を推奨:

```yaml
# analysis_options.yaml
linter:
  rules:
    - always_use_package_imports
```

これで全てのimportが`package:`形式になり、`import_guard.yaml`の設定がシンプルになる。

## 実行

```bash
dart run custom_lint
```

## ライセンス

MIT
