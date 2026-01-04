import 'package:import_guard_core/import_guard_core.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('ImportGuardConfig', () {
    test('parses deny list from yaml', () {
      final yaml = loadYaml('''
deny:
  - package:my_app/data/**
  - package:my_app/presentation/**
  - dart:mirrors
''') as YamlMap;

      final config = ImportGuardConfig.fromYaml(yaml, '/app/lib/domain');

      expect(config.deny, [
        'package:my_app/data/**',
        'package:my_app/presentation/**',
        'dart:mirrors',
      ]);
      expect(config.configDir, '/app/lib/domain');
    });

    test('handles empty deny list', () {
      final yaml = loadYaml('''
deny: []
''') as YamlMap;

      final config = ImportGuardConfig.fromYaml(yaml, '/app');

      expect(config.deny, isEmpty);
    });

    test('handles missing deny key', () {
      final yaml = loadYaml('''
other_key: value
''') as YamlMap;

      final config = ImportGuardConfig.fromYaml(yaml, '/app');

      expect(config.deny, isEmpty);
    });

    test('parses relative patterns', () {
      final yaml = loadYaml('''
deny:
  - ../presentation/**
  - ./internal/*
''') as YamlMap;

      final config = ImportGuardConfig.fromYaml(yaml, '/app/lib/domain');

      expect(config.deny, [
        '../presentation/**',
        './internal/*',
      ]);
    });
  });
}
