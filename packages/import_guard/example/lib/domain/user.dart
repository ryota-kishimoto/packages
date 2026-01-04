// OK: domain can import domain
import 'package:import_guard_example/domain/entity.dart';
// NG: domain cannot import presenter
// expect_lint: import_guard
import 'package:import_guard_example/presenter/widget.dart';

class User extends Entity {
  final String name;
  User(this.name) : super('user-1');

  UserWidget get widget => UserWidget();
}
