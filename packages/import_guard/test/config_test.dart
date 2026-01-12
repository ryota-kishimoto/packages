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

      // Create pubspec.yaml to mark package root (used as root for config scanning)
      File(p.join(repoRoot, 'pubspec.yaml')).writeAsStringSync('name: test\n');
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
      // Update pubspec.yaml with package name
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
      // pubspec.yaml already exists from setUp

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

    test('10000 getConfigsForFile calls complete within 200ms', () {
      // Create complex folder structure
      final lib = Directory(p.join(repoRoot, 'lib'))..createSync();

      // Domain layer
      final domain = Directory(p.join(lib.path, 'domain'))..createSync();
      final entities = Directory(p.join(domain.path, 'entities'))..createSync();
      final usecases = Directory(p.join(domain.path, 'usecases'))..createSync();
      final repositories = Directory(p.join(domain.path, 'repositories'))
        ..createSync();

      // Data layer
      final data = Directory(p.join(lib.path, 'data'))..createSync();
      final sources = Directory(p.join(data.path, 'sources'))..createSync();
      final local = Directory(p.join(sources.path, 'local'))..createSync();
      final remote = Directory(p.join(sources.path, 'remote'))..createSync();
      final models = Directory(p.join(data.path, 'models'))..createSync();

      // Presentation layer
      final presentation = Directory(p.join(lib.path, 'presentation'))
        ..createSync();
      final pages = Directory(p.join(presentation.path, 'pages'))..createSync();
      final home = Directory(p.join(pages.path, 'home'))..createSync();
      final settings = Directory(p.join(pages.path, 'settings'))..createSync();
      final profile = Directory(p.join(pages.path, 'profile'))..createSync();
      final widgets = Directory(p.join(presentation.path, 'widgets'))
        ..createSync();
      final common = Directory(p.join(widgets.path, 'common'))..createSync();
      final specific = Directory(p.join(widgets.path, 'specific'))..createSync();

      // Create import_guard.yaml files at various levels
      File(p.join(lib.path, 'import_guard.yaml')).writeAsStringSync('''
deny:
  - dart:mirrors
  - dart:developer
''');

      File(p.join(domain.path, 'import_guard.yaml')).writeAsStringSync('''
deny:
  - package:http/**
  - package:dio/**
''');

      File(p.join(entities.path, 'import_guard.yaml')).writeAsStringSync('''
deny:
  - dart:io
''');

      File(p.join(data.path, 'import_guard.yaml')).writeAsStringSync('''
allow:
  - package:myapp/data/**
  - package:myapp/domain/**
''');

      File(p.join(remote.path, 'import_guard.yaml')).writeAsStringSync('''
allow:
  - package:http/**
  - package:dio/**
''');

      File(p.join(presentation.path, 'import_guard.yaml')).writeAsStringSync('''
deny:
  - package:myapp/data/**
''');

      File(p.join(settings.path, 'import_guard.yaml')).writeAsStringSync('''
inherit: false
deny:
  - dart:mirrors
''');

      // All directories to test
      final allDirs = [
        lib,
        domain,
        entities,
        usecases,
        repositories,
        data,
        sources,
        local,
        remote,
        models,
        presentation,
        pages,
        home,
        settings,
        profile,
        widgets,
        common,
        specific,
      ];

      final cache = ConfigCache();

      // Warm up - trigger initial scan
      cache.getConfigsForFile(p.join(lib.path, 'main.dart'));

      // Now measure 10000 calls across all directories
      final stopwatch = Stopwatch()..start();

      for (var i = 0; i < 10000; i++) {
        final dir = allDirs[i % allDirs.length];
        cache.getConfigsForFile(p.join(dir.path, 'file_$i.dart'));
      }

      stopwatch.stop();

      // Must complete within 200ms
      // If caching works properly, 10000 hash lookups should be very fast
      // Using 200ms threshold for CI stability across different environments
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(200),
        reason:
            '10000 getConfigsForFile calls took ${stopwatch.elapsedMilliseconds}ms, expected < 200ms',
      );

      // Print actual time for visibility
      // ignore: avoid_print
      print(
          'Performance: 10000 calls completed in ${stopwatch.elapsedMilliseconds}ms');
    });
  });
}
