// OK: presenter can import domain (no restriction on presenter)
import 'package:import_guard_example/domain/entity.dart';

class UserWidget {
  final String title = 'User Widget';

  Entity get entity => Entity('widget-entity');
}
