import 'dart:math';

import 'package:agamepad/app/components/inner_shadow.dart';
import 'package:agamepad/app/controllers/gamepad_theme_controller.dart';
import 'package:agamepad/app/data/models/gamepad_descriptor.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';

enum ShoulderButtonType {
  l1, // Top shoulder, rotated -45deg, top circular, bottom 50%
  l2, // Bottom shoulder, rotated 45deg, bottom circular, top 50%
  r1, // Top shoulder, rotated -45deg, top circular, bottom 50%
  r2, // Bottom shoulder, rotated 45deg, bottom circular, top 50%
}

class ShoulderButtonController extends GetxController {
  final String label;
  final GamepadButton button;
  final ShoulderButtonType type;
  final void Function(GamepadButton) onDown;
  final void Function(GamepadButton) onUp;

  ShoulderButtonController(
    this.label,
    this.button,
    this.type,
    this.onDown,
    this.onUp,
  );

  var pressed = false.obs;
  bool get isActive => pressed.value;
}

class ShoulderButton extends StatelessWidget {
  final String label;
  final GamepadButton button;
  final ShoulderButtonType type;
  final void Function(GamepadButton) onDown;
  final void Function(GamepadButton) onUp;

  const ShoulderButton({
    super.key,
    required this.onDown,
    required this.onUp,
    required this.label,
    required this.button,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final controller = ShoulderButtonController(
      label,
      button,
      type,
      onDown,
      onUp,
    );

    // Determine rotation angle based on left/right side
    final isLeftShoulder =
        controller.type == ShoulderButtonType.l1 ||
        controller.type == ShoulderButtonType.l2;
    final rotation = isLeftShoulder
        ? -45.0
        : 45.0; // -45 for left, 45 for right

    // Determine if this is a top button (L1/R1) or bottom button (L2/R2)
    final isTopButton =
        controller.type == ShoulderButtonType.l1 ||
        controller.type == ShoulderButtonType.r1;

    return Transform.rotate(
      angle: rotation * pi / 180, // Convert degrees to radians
      alignment: Alignment.center, // Rotate around center
      child: Listener(
        onPointerDown: (_) {
          controller.onDown(controller.button);
          controller.pressed.value = true;
        },
        onPointerUp: (_) {
          controller.onUp(controller.button);
          controller.pressed.value = false;
        },
        onPointerCancel: (_) {
          controller.onUp(controller.button);
          controller.pressed.value = false;
        },
        child: Obx(() {
          final themeController = Get.find<GamepadThemeController>();
          final backgroundColor = themeController.getBackgroundColor(
            button.toString(),
            controller.isActive,
          );
          final innerShadows = themeController.getInnerShadows(
            button.toString(),
            controller.isActive,
          );

          return DecoratedBox(
            decoration: InsetShadowShapeDecoration(
              shape: RoundedRectangleBorder(
                borderRadius: isTopButton
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(100),
                        topRight: Radius.circular(100),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      )
                    : const BorderRadius.only(
                        bottomLeft: Radius.circular(100),
                        bottomRight: Radius.circular(100),
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
              ),
              shadows: innerShadows
                  .map(
                    (shadow) => InsetBoxShadow(
                      color: shadow.color,
                      blurRadius: shadow.blurRadius,
                      spreadRadius: shadow.spreadRadius,
                      offset: shadow.offset,
                    ),
                  )
                  .toList(),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: isTopButton
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(100),
                        topRight: Radius.circular(100),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      )
                    : const BorderRadius.only(
                        bottomLeft: Radius.circular(100),
                        bottomRight: Radius.circular(100),
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                color: backgroundColor,
              ),
              child: Center(
                child: Transform.rotate(
                  angle: -rotation * pi / 180,
                  alignment: Alignment.center,
                  child: Text(
                    controller.label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: controller.pressed.value
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
