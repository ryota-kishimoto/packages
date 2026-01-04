import 'package:import_guard_core/import_guard_core.dart';
import 'package:test/test.dart';

void main() {
  group('PatternTrie', () {
    group('exact/prefix patterns', () {
      test('matches exact import', () {
        final trie = PatternTrie()..insert('dart:mirrors');

        expect(trie.matches('dart:mirrors'), isTrue);
        expect(trie.matches('dart:async'), isFalse);
      });

      test('matches prefix (package without glob)', () {
        final trie = PatternTrie()..insert('package:flutter');

        expect(trie.matches('package:flutter'), isTrue);
        expect(trie.matches('package:flutter/material.dart'), isTrue);
        expect(trie.matches('package:flutter/widgets/button.dart'), isTrue);
        expect(trie.matches('package:other'), isFalse);
      });
    });

    group('/** patterns (all descendants)', () {
      test('matches all descendants', () {
        final trie = PatternTrie()..insert('package:my_app/data/**');

        expect(trie.matches('package:my_app/data/repo.dart'), isTrue);
        expect(trie.matches('package:my_app/data/remote/api.dart'), isTrue);
        expect(trie.matches('package:my_app/data/local/db/schema.dart'), isTrue);
        expect(trie.matches('package:my_app/domain/user.dart'), isFalse);
      });
    });

    group('/* patterns (direct children only)', () {
      test('matches direct children only', () {
        final trie = PatternTrie()..insert('package:my_app/data/*');

        expect(trie.matches('package:my_app/data/repo.dart'), isTrue);
        expect(trie.matches('package:my_app/data/remote/api.dart'), isFalse);
        expect(trie.matches('package:my_app/domain/user.dart'), isFalse);
      });
    });

    group('multiple patterns', () {
      test('matches any of multiple patterns', () {
        final trie = PatternTrie()
          ..insert('package:my_app/data/**')
          ..insert('package:my_app/presentation/**')
          ..insert('dart:mirrors');

        expect(trie.matches('package:my_app/data/repo.dart'), isTrue);
        expect(trie.matches('package:my_app/presentation/page.dart'), isTrue);
        expect(trie.matches('dart:mirrors'), isTrue);
        expect(trie.matches('package:my_app/domain/user.dart'), isFalse);
        expect(trie.matches('dart:async'), isFalse);
      });

      test('handles overlapping patterns', () {
        final trie = PatternTrie()
          ..insert('package:my_app/**')
          ..insert('package:my_app/data/*');

        // Both should match via package:my_app/**
        expect(trie.matches('package:my_app/data/repo.dart'), isTrue);
        expect(trie.matches('package:my_app/data/remote/api.dart'), isTrue);
        expect(trie.matches('package:my_app/other/file.dart'), isTrue);
      });
    });

    group('edge cases', () {
      test('empty trie matches nothing', () {
        final trie = PatternTrie();

        expect(trie.matches('package:anything'), isFalse);
        expect(trie.matches('dart:mirrors'), isFalse);
      });

      test('handles deep nesting', () {
        final trie = PatternTrie()
          ..insert('package:my_app/a/b/c/d/**');

        expect(trie.matches('package:my_app/a/b/c/d/e.dart'), isTrue);
        expect(trie.matches('package:my_app/a/b/c/d/e/f/g.dart'), isTrue);
        expect(trie.matches('package:my_app/a/b/c/other.dart'), isFalse);
      });
    });

    group('stats', () {
      test('reports correct statistics', () {
        final trie = PatternTrie()
          ..insert('package:a/**')
          ..insert('package:b/**')
          ..insert('package:a/c/**');

        final stats = trie.stats;
        expect(stats['patterns'], 3);
        expect(stats['nodes'], greaterThan(3));
      });
    });
  });
}
