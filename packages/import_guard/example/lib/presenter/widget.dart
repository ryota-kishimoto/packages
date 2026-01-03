// OK - presenter can import domain (no restriction on presenter)
import '../domain/entity.dart';

class UserWidget {
  final String title = 'User Widget';

  // Use imported class to avoid unused_import warning
  Entity get entity => Entity('widget-entity');
}
