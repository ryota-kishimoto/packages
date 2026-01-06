/// Base entity class for the domain layer.
///
/// This file is in lib/domain/ directory.
/// Rules applied:
///   - example/import_guard.yaml (inherited)
///   - lib/domain/import_guard.yaml

/// A base entity with an ID.
class Entity {
  final String id;
  Entity(this.id);
}
