import 'package:get/get.dart';

import '../controllers/gamepad_controller.dart';

class GamepadBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<GamepadController>(
      () => GamepadController(),
    );
  }
}
