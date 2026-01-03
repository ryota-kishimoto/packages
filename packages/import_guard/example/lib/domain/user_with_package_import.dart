// OK: domain can import domain
import 'package:import_guard_example/domain/entity.dart';
// NG: domain cannot import infrastructure
import 'package:import_guard_example/infrastructure/user_repository.dart';

class UserWithInfraImport extends Entity {
  final String name;
  UserWithInfraImport(this.name) : super('user-2');

  UserRepository get repository => UserRepository();
}
