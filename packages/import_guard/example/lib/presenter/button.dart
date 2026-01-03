// OK: presenter can import presenter
import 'package:import_guard_example/presenter/widget.dart';

class Button {
  final UserWidget parent;
  Button(this.parent);
}
