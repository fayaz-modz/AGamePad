import 'package:agamepad/app/components/inner_shadow.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/test_ui_controller.dart';

class TestUiView extends GetView<TestUiController> {
  const TestUiView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red,
      body: SizedBox(
        width: 100,
        height: 100,
        child: Center(
          child: DecoratedBox(
            decoration: InsetShadowShapeDecoration(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              shadows: [
                InsetBoxShadow(
                  color: Colors.white.withValues(alpha: 0.3),
                  offset: Offset(-10, 0),
                  blurRadius: 10,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: const SizedBox(width: 500, height: 200),
          ),
        ),
      ),
    );
  }
}
