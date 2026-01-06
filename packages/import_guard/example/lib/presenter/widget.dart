/// Presenter layer widget demonstrating clean architecture rules.
///
/// This file is in lib/presenter/ directory.
/// Rules applied: example/import_guard.yaml (inherited)
///
/// Note: Presenter layer CAN import from domain layer.

import 'package:import_guard_example/domain/user.dart';

/// Base widget class.
abstract class Widget {
  void render();
}

/// A widget that displays a user.
class UserWidget implements Widget {
  final User user;

  UserWidget({required this.user});

  @override
  void render() {
    print('Rendering user: ${user.name}');
  }
}
