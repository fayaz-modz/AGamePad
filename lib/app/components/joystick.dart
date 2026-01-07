import 'dart:math';

import 'package:agamepad/app/components/inner_shadow.dart';
import 'package:agamepad/app/controllers/gamepad_theme_controller.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';

class JoystickController extends GetxController {
  final ValueChanged<Offset> onChanged;
  JoystickController(this.onChanged);

  Rx<Alignment> alignment = Alignment.center.obs;
  Rx<int> activePointerId =
      (-1).obs; // Track which pointer is controlling this joystick

  void updatePosition(Offset localPosition, double size) {
    final center = size / 2;
    final dx = localPosition.dx - center;
    final dy = localPosition.dy - center;
    final distance = sqrt(dx * dx + dy * dy);

    // Normalize to -1..1
    double nx = dx / (size / 2);
    double ny = dy / (size / 2);

    if (distance > size / 2) {
      final ratio = (size / 2) / distance;
      nx *= ratio;
      ny *= ratio;
    }

    alignment.value = Alignment(nx, ny);

    onChanged(Offset(nx.clamp(-1.0, 1.0), ny.clamp(-1.0, 1.0)));
  }

  void reset() {
    alignment.value = Alignment.center;
    onChanged(Offset.zero);
  }

  Widget? cachedBackground;
  Widget? cachedKnob;
  double? cachedSize;

  Widget _JoystickBackground({required double size}) {
    final themeController = Get.find<GamepadThemeController>();

    return GetBuilder<GamepadThemeController>(
      builder: (theme) {
        final backgroundColor = theme.getBackgroundColor(
          'joystick_background',
          false,
        );
        final innerShadows = theme.getInnerShadows(
          'joystick_background',
          false,
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
            child: const SizedBox(
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        );
      },
    );
  }

  Widget _JoystickKnob({required double size}) {
    final themeController = Get.find<GamepadThemeController>();

    return GetBuilder<GamepadThemeController>(
      builder: (theme) {
        final backgroundColor = theme.getBackgroundColor(
          'joystick_knob',
          false,
        );
        final innerShadows = theme.getInnerShadows('joystick_knob', false);

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
          ),
        );
      },
    );
  }
}

class JoystickComp extends StatelessWidget {
  final ValueChanged<Offset> onChanged;
  const JoystickComp({super.key, required this.onChanged});

  Widget _JoystickBackground({required double size}) {
    final themeController = Get.find<GamepadThemeController>();

    return GetBuilder<GamepadThemeController>(
      builder: (theme) {
        final backgroundColor = theme.getBackgroundColor(
          'joystick_background',
          false,
        );
        final innerShadows = theme.getInnerShadows(
          'joystick_background',
          false,
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
            child: const SizedBox(
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        );
      },
    );
  }

  Widget _JoystickKnob({required double size}) {
    final themeController = Get.find<GamepadThemeController>();

    return GetBuilder<GamepadThemeController>(
      builder: (theme) {
        final backgroundColor = theme.getBackgroundColor(
          'joystick_knob',
          false,
        );
        final innerShadows = theme.getInnerShadows('joystick_knob', false);

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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = JoystickController(onChanged);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Enforce square aspect ratio for the joystick area
        final actualSize = min(constraints.maxWidth, constraints.maxHeight);
        final knobSize =
            actualSize / 2.0; // Increased from 2.5 to 2.0 for bigger knob

        // Rebuild cached widgets only if size changes
        if (actualSize != controller.cachedSize) {
          controller.cachedSize = actualSize;

          controller.cachedBackground = _JoystickBackground(size: actualSize);

          controller.cachedKnob = _JoystickKnob(size: knobSize);
        }

        return Center(
          child: SizedBox(
            width: actualSize,
            height: actualSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Static Background with Shadows
                controller.cachedBackground!,

                // Interactive Layer
                Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (event) {
                    if (controller.activePointerId.value == -1) {
                      controller.activePointerId.value = event.pointer;
                      controller.updatePosition(
                        event.localPosition,
                        actualSize,
                      );
                    }
                  },
                  onPointerMove: (event) {
                    if (controller.activePointerId.value == event.pointer) {
                      controller.updatePosition(
                        event.localPosition,
                        actualSize,
                      );
                    }
                  },
                  onPointerUp: (event) {
                    if (controller.activePointerId.value == event.pointer) {
                      controller.activePointerId.value = -1;
                      controller.reset();
                    }
                  },
                  onPointerCancel: (event) {
                    if (controller.activePointerId.value == event.pointer) {
                      controller.activePointerId.value = -1;
                      controller.reset();
                    }
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Knob
                      Obx(() {
                        return Positioned(
                          left:
                              (actualSize / 2) +
                              (controller.alignment.value.x *
                                  (actualSize / 2)) -
                              (knobSize / 2),
                          top:
                              (actualSize / 2) +
                              (controller.alignment.value.y *
                                  (actualSize / 2)) -
                              (knobSize / 2),
                          child: controller.cachedKnob!,
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
