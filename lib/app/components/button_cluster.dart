import 'dart:math';

import 'package:agamepad/app/components/inner_shadow.dart';
import 'package:agamepad/app/controllers/gamepad_theme_controller.dart';
import 'package:agamepad/app/data/models/gamepad_descriptor.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';

class ButtonCluster extends GetView {
  final GamepadDescriptor descriptor;
  final void Function(GamepadButton) onDown;
  final void Function(GamepadButton) onUp;

  // Custom mappings
  final GamepadButton buttonBottom;
  final GamepadButton buttonRight;
  final GamepadButton buttonLeft;
  final GamepadButton buttonTop;
  final GamepadButton? buttonC;
  final GamepadButton? buttonZ;

  const ButtonCluster({
    super.key,
    required this.descriptor,
    required this.onDown,
    required this.buttonBottom,
    required this.onUp,
    required this.buttonRight,
    required this.buttonLeft,
    required this.buttonTop,
    required this.buttonC,
    required this.buttonZ,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        // For 6-button layout (wider), use height as base size to fill vertical space
        // For 4-button layout (square), use min dimension
        final has6Buttons = buttonC != null;
        final size = has6Buttons ? height : min(width, height);

        // Button size as fraction of container
        // 6-buttons: larger fraction of height (since it's wider)
        final btnSizeFraction = has6Buttons ? 0.38 : 0.35;
        final btnSize = size * btnSizeFraction;

        // Calculate spacing for cluster formation
        final spacing = has6Buttons ? btnSize * 0.8 : btnSize * 0.85;

        // Center point of the container
        final centerX = width / 2;
        final centerY = height / 2;

        // Offset to center the entire group horizontally
        // For 6-buttons: geometric center of {-spacing, +spacing*2.0} is +0.5*spacing.
        // So we shift left by 0.5*spacing to center it at 0.
        final groupOffsetX = has6Buttons ? -spacing * 0.5 : 0.0;

        return Stack(
          children: [
            // Button 1 (Bottom) - centered horizontally, below center
            Positioned(
              left: centerX + groupOffsetX - btnSize / 2,
              top: centerY + spacing - btnSize / 2,
              child: _RoundButton(
                descriptor.getButtonLabel(buttonBottom),
                Colors.green,
                buttonBottom,
                onDown,
                onUp,
                btnSize,
              ),
            ),
            // Button 2 (Right) - right of center
            Positioned(
              left: centerX + spacing + groupOffsetX - btnSize / 2,
              top: centerY - btnSize / 2,
              child: _RoundButton(
                descriptor.getButtonLabel(buttonRight),
                Colors.red,
                buttonRight,
                onDown,
                onUp,
                btnSize,
              ),
            ),
            // Button 3 (Left) - left of center
            Positioned(
              left: centerX - spacing + groupOffsetX - btnSize / 2,
              top: centerY - btnSize / 2,
              child: _RoundButton(
                descriptor.getButtonLabel(buttonLeft),
                Colors.blue,
                buttonLeft,
                onDown,
                onUp,
                btnSize,
              ),
            ),
            // Button 4 (Top) - centered horizontally, above center
            Positioned(
              left: centerX + groupOffsetX - btnSize / 2,
              top: centerY - spacing - btnSize / 2,
              child: _RoundButton(
                descriptor.getButtonLabel(buttonTop),
                Colors.amber,
                buttonTop,
                onDown,
                onUp,
                btnSize,
              ),
            ),

            // C Button (Bottom Right for 6-button layout)
            if (buttonC != null)
              Positioned(
                left: centerX + spacing * 2.0 + groupOffsetX - btnSize / 2,
                top: centerY + spacing * 0.85 - btnSize / 2,
                child: _RoundButton(
                  descriptor.getButtonLabel(buttonC!),
                  Colors.purple,
                  buttonC!,
                  onDown,
                  onUp,
                  btnSize,
                ),
              ),
            // Z Button (Top Right for 6-button layout)
            if (buttonZ != null)
              Positioned(
                left: centerX + spacing * 2.0 + groupOffsetX - btnSize / 2,
                top: centerY - spacing * 0.85 - btnSize / 2,
                child: _RoundButton(
                  descriptor.getButtonLabel(buttonZ!),
                  Colors.cyan,
                  buttonZ!,
                  onDown,
                  onUp,
                  btnSize,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RoundButtonController extends GetxController {
  var pressed = false.obs;
  bool get isActive => pressed.value;
}

class _RoundButton extends GetView {
  final String label;
  final Color color; // Kept for API compatibility but not used
  final GamepadButton button;
  final void Function(GamepadButton) onDown;
  final void Function(GamepadButton) onUp;
  final double size;

  const _RoundButton(
    this.label,
    this.color,
    this.button,
    this.onDown,
    this.onUp,
    this.size,
  );

  @override
  Widget build(BuildContext context) {
    final controller = _RoundButtonController();

    return Listener(
      onPointerDown: (_) {
        onDown(button);
        controller.pressed.value = true;
      },
      onPointerUp: (_) {
        onUp(button);
        controller.pressed.value = false;
      },
      onPointerCancel: (_) {
        onUp(button);
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

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor,
          ),
          child: DecoratedBox(
            decoration: InsetShadowShapeDecoration(
              shape: const CircleBorder(),
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
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.4,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
