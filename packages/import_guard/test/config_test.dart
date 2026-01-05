import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../lib/src/core/core.dart';

void main() {
  group('ImportGuardConfig', () {
    test('parses deny list from yaml', () {
      final yaml = loadYaml('''
deny:
  - package:my_app/data/**
  - package:my_app/presentation/**
  - dart:mirrors
''') as YamlMap;

      final config = ImportGuardConfig.fromYaml(
        yaml,
        '/app/lib/domain',
        '/app/lib/domain/import_guard.yaml',
      );

      expect(config.deny, [
        'package:my_app/data/**',
        'package:my_app/presentation/**',
        'dart:mirrors',
      ]);
      expect(config.configDir, '/app/lib/domain');
      expect(config.configFilePath, '/app/lib/domain/import_guard.yaml');
    });

    test('handles empty deny list', () {
      final yaml = loadYaml('''
deny: []
''') as YamlMap;

      final config = ImportGuardConfig.fromYaml(
        yaml,
        '/app',
        '/app/import_guard.yaml',
      );

      expect(config.deny, isEmpty);
    });

    test('handles missing deny key', () {
      final yaml = loadYaml('''
other_key: value
''') as YamlMap;

      final config = ImportGuardConfig.fromYaml(
        yaml,
        '/app',
        '/app/import_guard.yaml',
      );

      expect(config.deny, isEmpty);
    });

    test('parses relative patterns', () {
      final yaml = loadYaml('''
deny:
  - ../presentation/**
  - ./internal/*
''') as YamlMap;

      final config = ImportGuardConfig.fromYaml(
        yaml,
        '/app/lib/domain',
        '/app/lib/domain/import_guard.yaml',
      );

      expect(config.deny, [
        '../presentation/**',
        './internal/*',
      ]);
    });

    test('stores configFilePath correctly', () {
      final yaml = loadYaml('''
deny:
  - dart:mirrors
''') as YamlMap;

      final config = ImportGuardConfig.fromYaml(
        yaml,
        '/project/lib/domain',
        '/project/lib/domain/import_guard.yaml',
      );

      expect(config.configFilePath, '/project/lib/domain/import_guard.yaml');
    });

    test('inherit defaults to true', () {
      final yaml = loadYaml('''
deny:
  - dart:mirrors
''') as YamlMap;

      final config = ImportGuardConfig.fromYaml(
        yaml,
        '/app/lib/domain',
        '/app/lib/domain/import_guard.yaml',
      );

      expect(config.inherit, isTrue);
    });

    test('parses inherit: false', () {
      final yaml = loadYaml('''
inherit: false
deny:
  - dart:mirrors
''') as YamlMap;

      final config = ImportGuardConfig.fromYaml(
        yaml,
        '/app/lib/legacy',
        '/app/lib/legacy/import_guard.yaml',
      );

      expect(config.inherit, isFalse);
    });

    test('parses inherit: true explicitly', () {
      final yaml = loadYaml('''
inherit: true
deny:
  - dart:mirrors
''') as YamlMap;

      final config = ImportGuardConfig.fromYaml(
        yaml,
        '/app/lib/domain',
        '/app/lib/domain/import_guard.yaml',
      );

      expect(config.inherit, isTrue);
    });
  });
}
