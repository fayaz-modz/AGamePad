import 'package:get/get.dart';

import '../controllers/test_ui_controller.dart';

class TestUiBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TestUiController>(
      () => TestUiController(),
    );
  }
}
