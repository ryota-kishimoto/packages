import 'package:path/path.dart' as p;

/// Utility class for matching import patterns.
class PatternMatcher {
  final String configDir;
  final String packageRoot;
  final String? packageName;

  PatternMatcher({
    required this.configDir,
    required this.packageRoot,
    this.packageName,
  });

  /// Check if an import matches a pattern.
  bool matches({
    required String importUri,
    required String pattern,
    required String filePath,
  }) {
    // Handle absolute patterns (package:, dart:)
    if (pattern.startsWith('package:') || pattern.startsWith('dart:')) {
      return matchesAbsolutePattern(importUri, pattern);
    }

    // Handle relative patterns (./, ../)
    if (pattern.startsWith('./') || pattern.startsWith('../')) {
      return _matchesRelativePattern(importUri, pattern, filePath);
    }

    return false;
  }

  /// Match absolute patterns like package:foo/bar or dart:mirrors.
  static bool matchesAbsolutePattern(String importUri, String pattern) {
    // Handle ** glob (all descendants)
    if (pattern.endsWith('/**')) {
      final prefix = pattern.substring(0, pattern.length - 3);
      return importUri.startsWith(prefix) && importUri.length > prefix.length;
    }

    // Handle * glob (direct children only)
    if (pattern.endsWith('/*')) {
      final prefix = pattern.substring(0, pattern.length - 2);
      if (!importUri.startsWith(prefix)) return false;
      final rest = importUri.substring(prefix.length);
      // Should have exactly one path segment after prefix
      return rest.startsWith('/') && !rest.substring(1).contains('/');
    }

    // Exact match or prefix match
    return importUri == pattern || importUri.startsWith('$pattern/');
  }

  /// Match relative patterns like ./foo or ../bar.
  bool _matchesRelativePattern(
    String importUri,
    String pattern,
    String filePath,
  ) {
    // Convert relative pattern to absolute path from config directory
    final absolutePatternPath = p.normalize(p.join(configDir, pattern));

    // Convert import URI to absolute path
    String? absoluteImportPath;

    if (importUri.startsWith('package:')) {
      // Convert package: import to file path
      absoluteImportPath = _packageImportToPath(importUri);
    } else if (importUri.startsWith('./') || importUri.startsWith('../')) {
      // Relative import from file location
      absoluteImportPath = p.normalize(p.join(p.dirname(filePath), importUri));
    } else if (!importUri.contains(':')) {
      // Simple relative import
      absoluteImportPath = p.normalize(p.join(p.dirname(filePath), importUri));
    }

    if (absoluteImportPath == null) return false;

    return pathMatchesPattern(absoluteImportPath, absolutePatternPath);
  }

  /// Convert package: import to absolute file path.
  String? _packageImportToPath(String importUri) {
    if (packageName == null) return null;

    // package:my_app/foo/bar.dart -> /path/to/package/lib/foo/bar.dart
    final packagePrefix = 'package:$packageName/';
    if (!importUri.startsWith(packagePrefix)) return null;

    final relativePath = importUri.substring(packagePrefix.length);
    return p.join(packageRoot, 'lib', relativePath);
  }

  /// Check if a file path matches a pattern path.
  static bool pathMatchesPattern(String filePath, String patternPath) {
    // Handle ** glob
    if (patternPath.endsWith('/**')) {
      final prefix = patternPath.substring(0, patternPath.length - 3);
      return filePath.startsWith(prefix);
    }

    // Handle * glob
    if (patternPath.endsWith('/*')) {
      final prefix = patternPath.substring(0, patternPath.length - 2);
      if (!filePath.startsWith(prefix)) return false;
      final rest = filePath.substring(prefix.length);
      // Should have exactly one path segment after prefix
      return rest.startsWith('/') && !rest.substring(1).contains('/');
    }

    // Exact match or prefix match
    return filePath == patternPath || filePath.startsWith('$patternPath/');
  }
}
