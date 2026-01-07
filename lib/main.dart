import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:get/get.dart';

import 'app/controllers/gamepad_theme_controller.dart';
import 'app/routes/app_pages.dart';

void main() {
  // Enable repaint boundary debugging
  debugRepaintRainbowEnabled = true;

  // Initialize theme controller
  Get.put(GamepadThemeController());

  runApp(
    GetMaterialApp(
      title: "Application",
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
    ),
  );
}
