// The module registry. A fifth shared-life module is a directory under modules/ and one line here:
// nothing under the existing modules changes, and Us picks it up on the next build.
import 'calendar/calendar_module.dart';
import 'dates/dates_module.dart';
import 'module.dart';
import 'rituals/rituals_module.dart';
import 'shelf/shelf_module.dart';
import 'todos/todos_module.dart';

const List<Module> kModules = [
  DatesModule(),
  TodosModule(),
  CalendarModule(),
  RitualsModule(),
  ShelfModule(),
];
