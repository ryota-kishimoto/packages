# import_guard

パッケージやフォルダ間のimportを制限するcustom_lintパッケージ。

## 特徴

- `import_guard.yaml`でフォルダごとにimport制限を定義
- globパターン: `package:my_app/data/**`, `package:flutter/**`
- package importと相対import両方に対応

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

## ライセンス

MIT
