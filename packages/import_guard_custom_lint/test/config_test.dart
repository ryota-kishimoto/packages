import 'dart:io';

import 'package:path/path.dart' as p;
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

    test('parses allow list from yaml', () {
      final yaml = loadYaml('''
allow:
  - package:my_app/domain/**
  - dart:core
  - dart:async
''') as YamlMap;

      final config = ImportGuardConfig.fromYaml(
        yaml,
        '/app/lib/domain',
        '/app/lib/domain/import_guard.yaml',
      );

      expect(config.allow, [
        'package:my_app/domain/**',
        'dart:core',
        'dart:async',
      ]);
      expect(config.hasAllowRules, isTrue);
    });

    test('allow defaults to empty list', () {
      final yaml = loadYaml('''
deny:
  - dart:mirrors
''') as YamlMap;

      final config = ImportGuardConfig.fromYaml(
        yaml,
        '/app/lib/domain',
        '/app/lib/domain/import_guard.yaml',
      );

      expect(config.allow, isEmpty);
      expect(config.hasAllowRules, isFalse);
    });

    test('parses allow and deny together', () {
      final yaml = loadYaml('''
allow:
  - package:my_app/**
deny:
  - package:my_app/data/**
''') as YamlMap;

      final config = ImportGuardConfig.fromYaml(
        yaml,
        '/app/lib/domain',
        '/app/lib/domain/import_guard.yaml',
      );

      expect(config.allow, ['package:my_app/**']);
      expect(config.deny, ['package:my_app/data/**']);
      expect(config.hasAllowRules, isTrue);
    });

    test('separates allow patterns into absolute and relative', () {
      final yaml = loadYaml('''
allow:
  - package:my_app/domain/**
  - ../utils/**
  - ./models/*
''') as YamlMap;

      final config = ImportGuardConfig.fromYaml(
        yaml,
        '/app/lib/domain',
        '/app/lib/domain/import_guard.yaml',
      );

      expect(config.allowPatternTrie.matches('package:my_app/domain/user.dart'),
          isTrue);
      expect(config.allowRelativePatterns, ['../utils/**', './models/*']);
    });
  });

  group('ConfigCache', () {
    late Directory tempDir;
    late String repoRoot;

    setUp(() {
      // Reset singleton state before each test
      ConfigCache().reset();

      tempDir = Directory.systemTemp.createTempSync('import_guard_test_');
      repoRoot = tempDir.path;

      // Create .git directory to mark repo root
      Directory(p.join(repoRoot, '.git')).createSync();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('getConfigsForFile returns cached result for same directory', () {
      // Create a config file
      final libDir = Directory(p.join(repoRoot, 'lib'));
      libDir.createSync();
      File(p.join(libDir.path, 'import_guard.yaml')).writeAsStringSync('''
deny:
  - dart:mirrors
''');

      // Create test files
      File(p.join(libDir.path, 'a.dart')).writeAsStringSync('');
      File(p.join(libDir.path, 'b.dart')).writeAsStringSync('');

      final cache = ConfigCache();

      // First call should load and cache
      final configsA = cache.getConfigsForFile(p.join(libDir.path, 'a.dart'));
      expect(configsA, hasLength(1));
      expect(configsA.first.deny, contains('dart:mirrors'));

      // Second call for same directory should return same cached list
      final configsB = cache.getConfigsForFile(p.join(libDir.path, 'b.dart'));
      expect(identical(configsA, configsB), isTrue,
          reason: 'Should return same cached List instance');
    });

    test('getPackageName returns cached result', () {
      // Create pubspec.yaml
      File(p.join(repoRoot, 'pubspec.yaml')).writeAsStringSync('''
name: test_package
''');

      final libDir = Directory(p.join(repoRoot, 'lib'));
      libDir.createSync();

      final cache = ConfigCache();

      // First call
      final name1 = cache.getPackageName(libDir.path);
      expect(name1, 'test_package');

      // Second call should return cached
      final name2 = cache.getPackageName(libDir.path);
      expect(name2, 'test_package');
    });

    test('getPackageRoot returns cached result', () {
      // Create pubspec.yaml
      File(p.join(repoRoot, 'pubspec.yaml')).writeAsStringSync('''
name: test_package
''');

      final libDir = Directory(p.join(repoRoot, 'lib'));
      libDir.createSync();
      final srcDir = Directory(p.join(libDir.path, 'src'));
      srcDir.createSync();

      final cache = ConfigCache();

      // Call for nested directory
      final root1 = cache.getPackageRoot(srcDir.path);
      expect(root1, repoRoot);

      // Call again should return cached
      final root2 = cache.getPackageRoot(srcDir.path);
      expect(root2, repoRoot);
    });

    test('scans all import_guard.yaml files once', () {
      // Create nested structure with multiple configs
      final libDir = Directory(p.join(repoRoot, 'lib'));
      libDir.createSync();
      final domainDir = Directory(p.join(libDir.path, 'domain'));
      domainDir.createSync();
      final dataDir = Directory(p.join(libDir.path, 'data'));
      dataDir.createSync();

      // Root config
      File(p.join(libDir.path, 'import_guard.yaml')).writeAsStringSync('''
deny:
  - dart:mirrors
''');

      // Domain config
      File(p.join(domainDir.path, 'import_guard.yaml')).writeAsStringSync('''
deny:
  - package:http/**
''');

      // Data config
      File(p.join(dataDir.path, 'import_guard.yaml')).writeAsStringSync('''
deny:
  - dart:io
''');

      File(p.join(domainDir.path, 'user.dart')).writeAsStringSync('');
      File(p.join(dataDir.path, 'repo.dart')).writeAsStringSync('');

      final cache = ConfigCache();

      // Get configs for domain file - should see domain + lib configs
      final domainConfigs =
          cache.getConfigsForFile(p.join(domainDir.path, 'user.dart'));
      expect(domainConfigs, hasLength(2));
      expect(domainConfigs[0].deny, contains('package:http/**'));
      expect(domainConfigs[1].deny, contains('dart:mirrors'));

      // Get configs for data file - should see data + lib configs
      final dataConfigs =
          cache.getConfigsForFile(p.join(dataDir.path, 'repo.dart'));
      expect(dataConfigs, hasLength(2));
      expect(dataConfigs[0].deny, contains('dart:io'));
      expect(dataConfigs[1].deny, contains('dart:mirrors'));
    });

    test('inherit: false stops config inheritance', () {
      final libDir = Directory(p.join(repoRoot, 'lib'));
      libDir.createSync();
      final legacyDir = Directory(p.join(libDir.path, 'legacy'));
      legacyDir.createSync();

      // Root config
      File(p.join(libDir.path, 'import_guard.yaml')).writeAsStringSync('''
deny:
  - dart:mirrors
''');

      // Legacy config with inherit: false
      File(p.join(legacyDir.path, 'import_guard.yaml')).writeAsStringSync('''
inherit: false
deny:
  - dart:io
''');

      File(p.join(legacyDir.path, 'old.dart')).writeAsStringSync('');

      final cache = ConfigCache();

      // Should only see legacy config, not lib config
      final configs =
          cache.getConfigsForFile(p.join(legacyDir.path, 'old.dart'));
      expect(configs, hasLength(1));
      expect(configs[0].deny, contains('dart:io'));
      expect(configs[0].inherit, isFalse);
    });
  });
}
