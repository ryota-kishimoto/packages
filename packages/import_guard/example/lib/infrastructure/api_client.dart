// OK: infrastructure can import infrastructure
import 'package:import_guard_example/infrastructure/user_repository.dart';

class ApiClient {
  final UserRepository repository;
  ApiClient(this.repository);
}
