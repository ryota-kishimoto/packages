import 'entity.dart';

// NG - should be flagged (domain cannot import presenter via package import)
import 'package:import_guard_example/presenter/widget.dart';

class UserWithPackageImport extends Entity {
  final String name;
  UserWithPackageImport(this.name) : super('user-2');

  // Use imported class to avoid unused_import warning
  UserWidget get widget => UserWidget();
}
