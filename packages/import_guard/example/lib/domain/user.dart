/// Example domain entity demonstrating clean architecture rules.
///
/// This file is in lib/domain/ directory.
/// Rules applied:
///   - example/import_guard.yaml (inherited)
///   - lib/domain/import_guard.yaml
///
/// ```yaml
/// # lib/domain/import_guard.yaml
/// deny:
///   - package:import_guard_example/presenter/**
/// ```

// OK: Domain layer can import within domain
import 'package:import_guard_example/domain/entity.dart';

// NG: Domain layer cannot import presenter layer
import 'package:import_guard_example/presenter/widget.dart';

/// A user entity in the domain layer.
class User extends Entity {
  final String name;

  User({required String id, required this.name}) : super(id);

  /// This demonstrates the violation - domain should not know about widgets.
  Widget toWidget() => UserWidget(user: this);
}
