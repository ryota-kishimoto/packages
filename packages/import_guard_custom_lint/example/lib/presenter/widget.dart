import 'package:import_guard_custom_lint_example/domain/user.dart';

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
