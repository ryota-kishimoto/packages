/// Match type for patterns.
enum MatchType {
  /// Exact match or prefix match (e.g., `package:foo` matches `package:foo/bar`)
  exact,

  /// Direct children only (e.g., `package:foo/*`)
  children,

  /// All descendants (e.g., `package:foo/**`)
  descendants,
}

/// A node in the pattern Trie.
class TrieNode {
  final Map<String, TrieNode> children = {};

  /// Non-null if this node represents the end of a pattern.
  MatchType? matchType;
}

/// A Trie data structure for efficient pattern matching.
///
/// Instead of checking each pattern one by one O(patterns × string_length),
/// we can match in O(string_length) by traversing the Trie once.
class PatternTrie {
  final TrieNode _root = TrieNode();

  /// Insert a pattern into the Trie.
  ///
  /// Supports:
  /// - `package:foo` (exact/prefix match)
  /// - `package:foo/*` (direct children only)
  /// - `package:foo/**` (all descendants)
  /// - `dart:mirrors` (exact match)
  void insert(String pattern) {
    MatchType matchType = MatchType.exact;
    String normalizedPattern = pattern;

    if (pattern.endsWith('/**')) {
      matchType = MatchType.descendants;
      normalizedPattern = pattern.substring(0, pattern.length - 3);
    } else if (pattern.endsWith('/*')) {
      matchType = MatchType.children;
      normalizedPattern = pattern.substring(0, pattern.length - 2);
    }

    final segments = _splitPattern(normalizedPattern);
    var node = _root;

    for (final segment in segments) {
      node = node.children.putIfAbsent(segment, () => TrieNode());
    }

    // Mark this node as end of pattern
    // If multiple patterns end at same node, prefer more restrictive
    if (node.matchType == null || matchType.index < node.matchType!.index) {
      node.matchType = matchType;
    }
  }

  /// Check if an import URI matches any pattern in the Trie.
  bool matches(String importUri) {
    final segments = _splitPattern(importUri);
    return _matchesRecursive(_root, segments, 0);
  }

  bool _matchesRecursive(TrieNode node, List<String> segments, int index) {
    // Check if current node is a pattern end
    if (node.matchType != null) {
      switch (node.matchType!) {
        case MatchType.descendants:
          // Matches anything from here
          return true;
        case MatchType.children:
          // Matches if exactly one more segment
          return index == segments.length - 1;
        case MatchType.exact:
          // Matches if we're at end OR there are more segments (prefix match)
          return true;
      }
    }

    // If no more segments, no match
    if (index >= segments.length) {
      return false;
    }

    // Try to continue down the trie
    final segment = segments[index];
    final child = node.children[segment];
    if (child != null) {
      return _matchesRecursive(child, segments, index + 1);
    }

    return false;
  }

  /// Split a pattern or import URI into segments.
  ///
  /// Examples:
  /// - `package:my_app/data/repo.dart` -> `[package:my_app, data, repo.dart]`
  /// - `dart:mirrors` -> `[dart:mirrors]`
  List<String> _splitPattern(String pattern) {
    // Handle package: and dart: prefixes
    if (pattern.startsWith('package:') || pattern.startsWith('dart:')) {
      final colonIndex = pattern.indexOf(':');
      final prefix = pattern.substring(0, colonIndex + 1);
      final rest = pattern.substring(colonIndex + 1);

      if (rest.isEmpty) {
        return [prefix];
      }

      final parts = rest.split('/');
      // Combine prefix with first part: "package:" + "my_app" = "package:my_app"
      return [prefix + parts.first, ...parts.skip(1)];
    }

    // Relative patterns or other
    return pattern.split('/');
  }

  /// Get statistics about the Trie (for debugging).
  Map<String, int> get stats {
    int nodeCount = 0;
    int patternCount = 0;

    void traverse(TrieNode node) {
      nodeCount++;
      if (node.matchType != null) patternCount++;
      for (final child in node.children.values) {
        traverse(child);
      }
    }

    traverse(_root);
    return {'nodes': nodeCount, 'patterns': patternCount};
  }
}
