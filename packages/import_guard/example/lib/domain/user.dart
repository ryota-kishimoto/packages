import 'entity.dart';

// NG - should be flagged (domain cannot import presenter)
import '../presenter/widget.dart';

class User extends Entity {
  final String name;
  User(this.name) : super('user-1');

  // Use imported class to avoid unused_import warning
  UserWidget get widget => UserWidget();
}
