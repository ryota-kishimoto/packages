# import_guard

パッケージやフォルダ間のimportを制限するanalyzer plugin。

> **Dart 3.10以上が必要**。古いDartバージョンでは[import_guard_custom_lint](https://pub.dev/packages/import_guard_custom_lint)を使用してください。

## 特徴

- `import_guard.yaml`でフォルダごとにimport制限を定義
- globパターン: `package:my_app/data/**`, `package:flutter/**`
- package importと相対import両方に対応
- リポジトリルートからの階層的な設定継承
- `dart analyze` / `flutter analyze`でのネイティブIDE統合

## インストール

```yaml
dependencies:
  import_guard: ^1.0.0
```

`analysis_options.yaml`で有効化:

```yaml
plugins:
  import_guard: ^1.0.0
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
dart analyze
# または
flutter analyze
```

## 関連パッケージ

- [import_guard_custom_lint](https://pub.dev/packages/import_guard_custom_lint) - custom_lint実装 (Dart 3.6+)
- [import_guard_core](https://pub.dev/packages/import_guard_core) - コアロジック

## ライセンス

MIT
