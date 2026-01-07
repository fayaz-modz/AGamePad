import 'package:agamepad/app/components/inner_shadow.dart';
import 'package:agamepad/app/controllers/gamepad_theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OptionButtonController extends GetxController {
  var pressed = false.obs;
  bool get isActive => pressed.value;
}

class OptionButton extends StatelessWidget {
  final String label;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final String? buttonId;

  const OptionButton({
    super.key,
    required this.label,
    required this.onDown,
    required this.onUp,
    this.buttonId,
  });

  @override
  Widget build(BuildContext context) {
    final controller = OptionButtonController();
    final themeController = Get.find<GamepadThemeController>();

    return Listener(
      onPointerDown: (_) {
        onDown();
        controller.pressed.value = true;
      },
      onPointerUp: (_) {
        onUp();
        controller.pressed.value = false;
      },
      onPointerCancel: (_) {
        onUp();
        controller.pressed.value = false;
      },
      child: Obx(() {
        final actualButtonId = buttonId ?? 'select';
        final backgroundColor = themeController.getBackgroundColor(
          actualButtonId,
          controller.isActive,
        );
        final innerShadows = themeController.getInnerShadows(
          actualButtonId,
          controller.isActive,
        );

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: backgroundColor,
          ),
          child: DecoratedBox(
            decoration: InsetShadowShapeDecoration(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: controller.isActive
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
