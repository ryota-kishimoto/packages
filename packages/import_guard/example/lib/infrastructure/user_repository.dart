// OK: infrastructure can import domain (no restriction on infrastructure)
import 'package:import_guard_example/domain/entity.dart';

class UserRepository {
  Entity findById(String id) => Entity(id);
}
