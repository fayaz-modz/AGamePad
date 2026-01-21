import 'dart:math';
import 'package:agamepad/app/components/button_cluster.dart';
import 'package:agamepad/app/components/dpad.dart';
import 'package:agamepad/app/components/joystick.dart';
import 'package:agamepad/app/components/option_button.dart';
import 'package:agamepad/app/components/shoulder_button.dart';
import 'package:agamepad/app/data/models/gamepad_descriptor.dart';
import 'package:agamepad/app/data/models/gamepad_layout.dart';
import 'package:agamepad/app/modules/gamepad/controllers/gamepad_controller.dart';
import 'package:agamepad/app/modules/test_ui/bindings/test_ui_binding.dart';
import 'package:agamepad/app/modules/test_ui/views/test_ui_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class GamepadView extends GetView<GamepadController> {
  const GamepadView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<GamepadController>(
      builder: (controller) {
        final size = MediaQuery.of(context).size;

        return Scaffold(
          backgroundColor: const Color(0xFF111111),
          body: Stack(
            clipBehavior:
                Clip.none, // Allow controls to overflow without clipping
            children: [
              // Background Trackpad Surface
              // This is placed first so it's behind all controls
              if (!controller.isEditing)
                Positioned.fill(
                  child: Listener(
                    onPointerDown: controller.onPointerDown,
                    onPointerUp: controller.onPointerUp,
                    onPointerMove: controller.onPointerMove,
                    behavior: HitTestBehavior.translucent,
                    child: Container(color: Colors.transparent),
                  ),
                ),

              // Render all controls from layout
              ...controller.layout.controls.map(
                (control) => _buildControl(context, control, size, controller),
              ),

              // Edit Toolkit - only show if in edit mode
              if (controller.isEditing) ...[
                Positioned(
                  top: 10,
                  right: 10,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.save, color: Colors.green),
                        onPressed: controller.saveLayout,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () {
                          Get.back();
                        },
                      ),
                    ],
                  ),
                ),

                const Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Text(
                      "EDIT MODE - Select a control to edit",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Edit Overlay for Selected Control
                if (controller.selectedControl != null)
                  Positioned(
                    top: 60,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: SizedBox(
                        width: 300,
                        child: Card(
                          color: Colors.black54,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Colors.white24),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8.0,
                              horizontal: 16.0,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Editing: ${controller.selectedControl!.getLabel(controller.descriptor)}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (controller.selectedControl!.type ==
                                        ControlType.dpad ||
                                    controller.selectedControl!.type ==
                                        ControlType.buttonCluster ||
                                    controller.selectedControl!.type ==
                                        ControlType.joystick)
                                  Row(
                                    children: [
                                      const Text(
                                        "Size",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                        ),
                                      ),
                                      Expanded(
                                        child: SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            thumbShape:
                                                const RoundSliderThumbShape(
                                                  enabledThumbRadius: 6,
                                                ),
                                            overlayShape:
                                                const RoundSliderOverlayShape(
                                                  overlayRadius: 12,
                                                ),
                                            trackHeight: 2,
                                          ),
                                          child: Slider(
                                            value: max(
                                              controller.selectedControl!.width,
                                              controller
                                                  .selectedControl!
                                                  .height,
                                            ).clamp(40.0, 300.0),
                                            min: 40,
                                            max: 300,
                                            activeColor: Colors.blueAccent,
                                            onChanged:
                                                controller.updateControlSize,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else ...[
                                  Row(
                                    children: [
                                      const SizedBox(
                                        width: 40,
                                        child: Text(
                                          "Width",
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            thumbShape:
                                                const RoundSliderThumbShape(
                                                  enabledThumbRadius: 6,
                                                ),
                                            overlayShape:
                                                const RoundSliderOverlayShape(
                                                  overlayRadius: 12,
                                                ),
                                            trackHeight: 2,
                                          ),
                                          child: Slider(
                                            value: controller
                                                .selectedControl!
                                                .width
                                                .clamp(30.0, 300.0),
                                            min: 30,
                                            max: 300,
                                            activeColor: Colors.blueAccent,
                                            onChanged:
                                                controller.updateControlWidth,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      const SizedBox(
                                        width: 40,
                                        child: Text(
                                          "Height",
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            thumbShape:
                                                const RoundSliderThumbShape(
                                                  enabledThumbRadius: 6,
                                                ),
                                            overlayShape:
                                                const RoundSliderOverlayShape(
                                                  overlayRadius: 12,
                                                ),
                                            trackHeight: 2,
                                          ),
                                          child: Slider(
                                            value: controller
                                                .selectedControl!
                                                .height
                                                .clamp(30.0, 300.0),
                                            min: 30,
                                            max: 300,
                                            activeColor: Colors.blueAccent,
                                            onChanged:
                                                controller.updateControlHeight,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => controller.editControl(
                                        controller.selectedControl!,
                                      ),
                                      icon: const Icon(
                                        Icons.settings,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      label: const Text(
                                        "Map",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 0,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          controller.clearSelectedControl(),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 0,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        "Done",
                                        style: TextStyle(
                                          color: Colors.greenAccent,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildControl(
    BuildContext context,
    GamepadControl control,
    Size screenSize,
    GamepadController controller,
  ) {
    // Edge-based positioning in pixels
    final width = control.width;
    final height = control.height;

    // Calculate left position (where left edge of control should be)
    final double left;
    if (control.centerHorizontal) {
      // Center horizontally with optional offset
      left = (screenSize.width / 2) - (width / 2) + control.offsetX;
    } else if (control.left != null) {
      // left represents distance from left edge to CENTER of control
      left = control.left! - (width / 2);
    } else {
      // right represents distance from right edge to CENTER of control
      final centerFromLeft = screenSize.width - control.right!;
      left = centerFromLeft - (width / 2);
    }

    // Calculate top position (where top edge of control should be)
    final double top;
    if (control.centerVertical) {
      // Center vertically with optional offset
      top = (screenSize.height / 2) - (height / 2) + control.offsetY;
    } else if (control.top != null) {
      // top represents distance from top edge to CENTER of control
      top = control.top! - (height / 2);
    } else {
      // bottom represents distance from bottom edge to CENTER of control
      final centerFromTop = screenSize.height - control.bottom!;
      top = centerFromTop - (height / 2);
    }

    // For D-pad, button cluster, joysticks, and shoulder buttons, enforce square dimensions
    final needsSquare =
        control.type == ControlType.dpad ||
        control.type == ControlType.joystick ||
        control.type == ControlType.shoulderButton;
    final actualWidth = needsSquare ? min(width, height) : width;
    final actualHeight = needsSquare ? min(width, height) : height;

    Widget child = _renderWidgetForControl(control, controller);

    // Highlight if selected
    if (controller.isEditing && controller.selectedControl == control) {
      child = Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.greenAccent, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.greenAccent.withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: 8,
            ),
          ],
        ),
        child: child,
      );
    }

    if (controller.isEditing) {
      return Positioned(
        left: left,
        top: top,
        width: actualWidth,
        height: actualHeight,
        child: GestureDetector(
          onPanUpdate: (details) {
            controller.updateControlPosition(
              control,
              details.delta,
              screenSize,
            );
          },
          onTap: () => controller.selectControl(control),
          child: Container(
            clipBehavior: Clip.none, // Allow overflow during editing too
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red, width: 2),
              color: Colors.black45,
            ),
            child: AbsorbPointer(child: child),
          ),
        ),
      );
    } else {
      return Positioned(
        left: left,
        top: top,
        width: actualWidth,
        height: actualHeight,
        child: child,
      );
    }
  }

  Widget _renderWidgetForControl(
    GamepadControl control,
    GamepadController controller,
  ) {
    switch (control.type) {
      case ControlType.joystick:
        return JoystickComp(
          onChanged: (val) => controller.onJoystickChange(
            control.joystickMapping ?? Joystick.left,
            val,
          ),
        );
      case ControlType.dpad:
        return Dpad(
          size: min(control.width, control.height),
          onDown: (val) {
            controller.setDpad(val);
          },
          onUp: () {
            controller.resetDpad();
          },
        );
      case ControlType.buttonCluster:
        return ButtonCluster(
          descriptor: controller.descriptor,
          onDown: controller.onButtonDown,
          onUp: controller.onButtonUp,
          buttonBottom: control.clusterBottom ?? GamepadButton.button1,
          buttonRight: control.clusterRight ?? GamepadButton.button2,
          buttonLeft: control.clusterLeft ?? GamepadButton.button3,
          buttonTop: control.clusterTop ?? GamepadButton.button4,
          buttonC: control.clusterC,
          buttonZ: control.clusterZ,
        );
      case ControlType.shoulderButton:
        // Determine shoulder button type
        ShoulderButtonType shoulderType;
        final button = control.buttonMapping ?? GamepadButton.l1;

        if (button == GamepadButton.l1) {
          shoulderType = ShoulderButtonType.l1;
        } else if (button == GamepadButton.l2) {
          shoulderType = ShoulderButtonType.l2;
        } else if (button == GamepadButton.r1) {
          shoulderType = ShoulderButtonType.r1;
        } else if (button == GamepadButton.r2) {
          shoulderType = ShoulderButtonType.r2;
        } else {
          // Default to l1 if unknown
          shoulderType = ShoulderButtonType.l1;
        }

        return ShoulderButton(
          label: control.getLabel(controller.descriptor),
          button: button,
          type: shoulderType,
          onDown: controller.onButtonDown,
          onUp: controller.onButtonUp,
        );
      case ControlType.button:
        return OptionButton(
          label: control.getLabel(controller.descriptor),
          buttonId: (control.buttonMapping ?? GamepadButton.select).toString(),
          onDown: () => controller.onButtonDown(
            control.buttonMapping ?? GamepadButton.select,
          ),
          onUp: () => controller.onButtonUp(
            control.buttonMapping ?? GamepadButton.select,
          ),
        );
    }
  }
}
