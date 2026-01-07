import 'package:get/get.dart';

import '../modules/connection/bindings/connection_binding.dart';
import '../modules/connection/views/connection_view.dart';
import '../modules/gamepad/bindings/gamepad_binding.dart';
import '../modules/gamepad/views/gamepad_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/test_ui/bindings/test_ui_binding.dart';
import '../modules/test_ui/views/test_ui_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.HOME;

  static final routes = [
    GetPage(
      name: _Paths.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.GAMEPAD,
      page: () => const GamepadView(),
      binding: GamepadBinding(),
    ),
    GetPage(
      name: _Paths.CONNECTION,
      page: () => const ConnectionView(),
      binding: ConnectionBinding(),
    ),
    GetPage(
      name: _Paths.TEST_UI,
      page: () => const TestUiView(),
      binding: TestUiBinding(),
    ),
  ];
}
