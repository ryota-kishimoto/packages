import 'package:test/test.dart';

import '../lib/src/core/core.dart';

void main() {
  group('matchesAbsolutePattern', () {
    group('exact match', () {
      test('matches exact package', () {
        expect(
          PatternMatcher.matchesAbsolutePattern(
            'package:flutter/material.dart',
            'package:flutter/material.dart',
          ),
          isTrue,
        );
      });

      test('matches package with subpath', () {
        expect(
          PatternMatcher.matchesAbsolutePattern(
            'package:my_app/domain/user.dart',
            'package:my_app/domain',
          ),
          isTrue,
        );
      });

      test('does not match different package', () {
        expect(
          PatternMatcher.matchesAbsolutePattern(
            'package:other_app/domain/user.dart',
            'package:my_app/domain',
          ),
          isFalse,
        );
      });

      test('matches dart: imports', () {
        expect(
          PatternMatcher.matchesAbsolutePattern('dart:mirrors', 'dart:mirrors'),
          isTrue,
        );
      });
    });

    group('/** pattern (all descendants)', () {
      test('matches direct child', () {
        expect(
          PatternMatcher.matchesAbsolutePattern(
            'package:my_app/data/repository.dart',
            'package:my_app/data/**',
          ),
          isTrue,
        );
      });

      test('matches nested child', () {
        expect(
          PatternMatcher.matchesAbsolutePattern(
            'package:my_app/data/remote/api_client.dart',
            'package:my_app/data/**',
          ),
          isTrue,
        );
      });

      test('does not match sibling', () {
        expect(
          PatternMatcher.matchesAbsolutePattern(
            'package:my_app/domain/user.dart',
            'package:my_app/data/**',
          ),
          isFalse,
        );
      });
    });

    group('/* pattern (direct children only)', () {
      test('matches direct child', () {
        expect(
          PatternMatcher.matchesAbsolutePattern(
            'package:my_app/data/repository.dart',
            'package:my_app/data/*',
          ),
          isTrue,
        );
      });

      test('does not match nested child', () {
        expect(
          PatternMatcher.matchesAbsolutePattern(
            'package:my_app/data/remote/api_client.dart',
            'package:my_app/data/*',
          ),
          isFalse,
        );
      });
    });
  });

  group('pathMatchesPattern', () {
    group('exact match', () {
      test('matches exact path', () {
        expect(
          PatternMatcher.pathMatchesPattern(
            '/app/lib/domain/user.dart',
            '/app/lib/domain/user.dart',
          ),
          isTrue,
        );
      });

      test('matches directory prefix', () {
        expect(
          PatternMatcher.pathMatchesPattern(
            '/app/lib/domain/user.dart',
            '/app/lib/domain',
          ),
          isTrue,
        );
      });
    });

    group('/** pattern', () {
      test('matches all descendants', () {
        expect(
          PatternMatcher.pathMatchesPattern(
            '/app/lib/data/remote/api.dart',
            '/app/lib/data/**',
          ),
          isTrue,
        );
      });
    });

    group('/* pattern', () {
      test('matches direct children only', () {
        expect(
          PatternMatcher.pathMatchesPattern(
            '/app/lib/data/repo.dart',
            '/app/lib/data/*',
          ),
          isTrue,
        );
      });

      test('does not match nested', () {
        expect(
          PatternMatcher.pathMatchesPattern(
            '/app/lib/data/remote/api.dart',
            '/app/lib/data/*',
          ),
          isFalse,
        );
      });
    });
  });

  group('PatternMatcher.matches', () {
    test('matches package import with absolute pattern', () {
      final matcher = PatternMatcher(
        configDir: '/app/lib/domain',
        packageRoot: '/app',
        packageName: 'my_app',
      );

      expect(
        matcher.matches(
          importUri: 'package:my_app/data/repository.dart',
          pattern: 'package:my_app/data/**',
          filePath: '/app/lib/domain/user.dart',
        ),
        isTrue,
      );
    });

    test('matches relative pattern with package import', () {
      final matcher = PatternMatcher(
        configDir: '/app/lib/domain',
        packageRoot: '/app',
        packageName: 'my_app',
      );

      expect(
        matcher.matches(
          importUri: 'package:my_app/data/repository.dart',
          pattern: '../data/**',
          filePath: '/app/lib/domain/user.dart',
        ),
        isTrue,
      );
    });

    test('does not match allowed import', () {
      final matcher = PatternMatcher(
        configDir: '/app/lib/domain',
        packageRoot: '/app',
        packageName: 'my_app',
      );

      expect(
        matcher.matches(
          importUri: 'package:my_app/domain/entity.dart',
          pattern: 'package:my_app/data/**',
          filePath: '/app/lib/domain/user.dart',
        ),
        isFalse,
      );
    });

    test('matches dart: library', () {
      final matcher = PatternMatcher(
        configDir: '/app/lib',
        packageRoot: '/app',
        packageName: 'my_app',
      );

      expect(
        matcher.matches(
          importUri: 'dart:mirrors',
          pattern: 'dart:mirrors',
          filePath: '/app/lib/main.dart',
        ),
        isTrue,
      );
    });
  });
}
