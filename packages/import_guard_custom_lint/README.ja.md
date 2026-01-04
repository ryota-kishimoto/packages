# import_guard_custom_lint

パッケージやフォルダ間のimportを制限するcustom_lintパッケージ。

> **Note**: Dart 3.10以上の場合は、ネイティブanalyzer plugin APIを使用する[import_guard](https://pub.dev/packages/import_guard)の利用を検討してください。IDEとの統合がより良好です。

## 特徴

- `import_guard.yaml`でフォルダごとにimport制限を定義
- globパターン: `package:my_app/data/**`, `package:flutter/**`
- package importと相対import両方に対応
- リポジトリルートからの階層的な設定継承

## インストール

```yaml
dev_dependencies:
  import_guard_custom_lint: ^0.0.1
  custom_lint: ^0.8.0
```

`analysis_options.yaml`で有効化:

```yaml
analyzer:
  plugins:
    - custom_lint
```

## 使い方

任意のディレクトリに`import_guard.yaml`を作成し、そのディレクトリ内のファイルに対するimport制限を定義。

### 例: クリーンアーキテクチャ

`my_app`というFlutterアプリの場合:

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

これでdomainレイヤーがpresentationやdataレイヤーをimportすることを防げる。

### パターンの種類

| パターン | マッチ対象 |
|---------|-----------|
| `package:my_app/data/**` | `lib/data/`配下の全ファイル |
| `package:my_app/data/*` | `lib/data/`直下のみ |
| `package:flutter/**` | 全てのflutter import |
| `dart:mirrors` | 特定のdartライブラリ |
| `../data/**` | 相対パスパターン |

### 推奨: package importを使用

設定をシンプルにするため、`always_use_package_imports`の有効化を推奨:

```yaml
# analysis_options.yaml
linter:
  rules:
    - always_use_package_imports
```

これでpackageパターンのみで設定可能（相対パスパターン不要）。

## 実行

```bash
dart run custom_lint
```

## 関連パッケージ

- [import_guard](https://pub.dev/packages/import_guard) - ネイティブanalyzer plugin (Dart 3.10+)
- [import_guard_core](https://pub.dev/packages/import_guard_core) - コアロジック

## ライセンス

MIT
