import 'dart:async';
import 'package:agamepad/app/controllers/connection_controller_controller.dart';
import 'package:agamepad/app/data/models/gamepad_descriptor.dart';
import 'package:agamepad/app/data/models/gamepad_layout.dart';
import 'package:agamepad/app/data/services/layout_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class GamepadController extends GetxController {
  final LayoutStorageService _storage = LayoutStorageService();
  final ConnectionController connectionController =
      Get.find<ConnectionController>();

  // Layout state
  final Rx<GamepadLayout> _layout = GamepadLayout.xbox().obs;

  // Hot reload support - reload layout from static definition
  void reloadLayout() {
    final currentId = _layout.value.id;
    if (currentId == 'xbox_default') {
      _layout.value = GamepadLayout.xbox();
    } else if (currentId == 'android_default') {
      _layout.value = GamepadLayout.android();
    }

    // Reinitialize descriptor and button mask
    _descriptor.value = GamepadDescriptor();
    _buttonMask = ButtonMaskBuilder(_descriptor.value);
  }

  final Rx<GamepadDescriptor> _descriptor = GamepadDescriptor().obs;
  late ButtonMaskBuilder _buttonMask;

  // Editing state
  final RxBool _isEditing = false.obs;
  final Rx<GamepadControl?> _selectedControl = Rx<GamepadControl?>(null);

  // Input state
  final RxInt _lx = 127.obs;
  final RxInt _ly = 127.obs;
  final RxInt _rx = 127.obs;
  final RxInt _ry = 127.obs;
  final RxInt _l2 = 0.obs;
  final RxInt _r2 = 0.obs;
  final RxInt _dpad = 8.obs;

  // Last sent state to avoid redundant reports
  int _lastButtons = 0;
  int _lastLx = 127;
  int _lastLy = 127;
  int _lastRx = 127;
  int _lastRy = 127;
  int _lastL2 = 0;
  int _lastR2 = 0;
  int _lastDpad = 8;

  // Batching flag to prevent multiple sends in same frame
  bool _sendScheduled = false;

  // Getters
  GamepadLayout get layout => _layout.value;
  GamepadDescriptor get descriptor => _descriptor.value;
  bool get isEditing => _isEditing.value;
  GamepadControl? get selectedControl => _selectedControl.value;
  int get lx => _lx.value;
  int get ly => _ly.value;
  int get rx => _rx.value;
  int get ry => _ry.value;
  int get l2 => _l2.value;
  int get r2 => _r2.value;
  int get dpad => _dpad.value;

  @override
  void onInit() {
    super.onInit();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadLayout();
  }

  @override
  void onClose() {
    connectionController.stopKeepalive();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.onClose();
  }

  Future<void> _loadLayout() async {
    final args = Get.arguments;

    // Handle both old format (just layout) and new format (map with layout and editMode)
    if (args is GamepadLayout) {
      _layout.value = args;
      _isEditing.value = false;
    } else if (args is Map) {
      _layout.value = args['layout'] as GamepadLayout;
      _isEditing.value = args['editMode'] as bool? ?? false;
    } else {
      // Default layout
      final layouts = await _storage.loadLayouts();
      _layout.value = layouts.isNotEmpty ? layouts.first : GamepadLayout.xbox();
      _isEditing.value = false;
    }

    // Initialize descriptor and button mask
    _descriptor.value = GamepadDescriptor();
    _buttonMask = ButtonMaskBuilder(_descriptor.value);

    // Start keepalive for connections
    connectionController.startKeepalive();
  }

  void sendUpdate() {
    if (_isEditing.value) return;

    // If a send is already scheduled, skip (batching)
    if (_sendScheduled) return;

    _sendScheduled = true;

    // Use scheduleMicrotask to batch multiple rapid calls into one send
    scheduleMicrotask(() {
      _sendScheduled = false;

      final currentButtons = _buttonMask.mask;

      // Only send if state has actually changed to minimize latency and overhead
      if (currentButtons == _lastButtons &&
          _lx.value == _lastLx &&
          _ly.value == _lastLy &&
          _rx.value == _lastRx &&
          _ry.value == _lastRy &&
          _l2.value == _lastL2 &&
          _r2.value == _lastR2 &&
          _dpad.value == _lastDpad) {
        return;
      }

      _lastButtons = currentButtons;
      _lastLx = _lx.value;
      _lastLy = _ly.value;
      _lastRx = _rx.value;
      _lastRy = _ry.value;
      _lastL2 = _l2.value;
      _lastR2 = _r2.value;
      _lastDpad = _dpad.value;

      connectionController.sendGamepadInput(
        buttons: currentButtons,
        lx: _lx.value,
        ly: _ly.value,
        rx: _rx.value,
        ry: _ry.value,
        l2: _l2.value,
        r2: _r2.value,
        dpad: _dpad.value,
      );
    });
  }

  void onButtonDown(GamepadButton button) {
    if (_isEditing.value) return;
    _buttonMask.press(button);
    if (button == GamepadButton.l2) _l2.value = 255;
    if (button == GamepadButton.r2) _r2.value = 255;
    sendUpdate();
  }

  void onButtonUp(GamepadButton button) {
    if (_isEditing.value) return;
    _buttonMask.release(button);
    if (button == GamepadButton.l2) _l2.value = 0;
    if (button == GamepadButton.r2) _r2.value = 0;
    sendUpdate();
  }

  void onJoystickChange(Joystick joystick, Offset value) {
    if (_isEditing.value) return;
    int map(double v) => ((v + 1.0) * 127.5).toInt().clamp(0, 255);

    // mapping 0 = Left Stick, 1 = Right Stick
    if (joystick == Joystick.left) {
      _lx.value = map(value.dx);
      _ly.value = map(value.dy);
    } else {
      _rx.value = map(value.dx);
      _ry.value = map(value.dy);
    }
    sendUpdate();
  }

  // Trackpad state
  int _mouseButtonState = 0;
  double _accumulatedDx = 0.0;
  double _accumulatedDy = 0.0;

  void onTrackpadPan(Offset delta) {
    if (_isEditing.value) return;

    // Sensitivity multiplier - user might want to configure this later
    const double sensitivity = 4.0;

    // Add new delta to accumulated fractional values
    double targetDx = (delta.dx * sensitivity) + _accumulatedDx;
    double targetDy = (delta.dy * sensitivity) + _accumulatedDy;

    // Extract the integer part for the report
    final int dx = targetDx.truncate();
    final int dy = targetDy.truncate();

    // Keep the fractional part for next time
    _accumulatedDx = targetDx - dx;
    _accumulatedDy = targetDy - dy;

    if (dx == 0 && dy == 0) return;

    connectionController.sendMouseInput(
      dx: dx,
      dy: dy,
      buttons: _mouseButtonState,
    );
  }

  // Custom gesture state
  int _activePointers = 0;
  DateTime _pointerDownTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastTapUpTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isDragging = false;
  bool _hasMoved = false;
  bool _potentialRightClick = false;
  DateTime _rightClickDownTime = DateTime.fromMillisecondsSinceEpoch(0);

  void onPointerDown(PointerDownEvent event) {
    if (_isEditing.value) return;
    _activePointers++;
    _hasMoved = false;

    if (_activePointers == 1) {
      _pointerDownTime = DateTime.now();

      // Reset accumulators on new touch
      _accumulatedDx = 0.0;
      _accumulatedDy = 0.0;

      // Start dragging but don't fire mouse down yet
      _isDragging = true;
    } else if (_activePointers == 2) {
      // Potential 2-finger tap (Right Click)
      _potentialRightClick = true;
      _rightClickDownTime = DateTime.now();
    }
  }

  void onPointerUp(PointerUpEvent event) {
    if (_isEditing.value) return;
    _activePointers = (_activePointers - 1).clamp(0, 10);
    final now = DateTime.now();

    // Handle Right Click (2-finger tap)
    if (_potentialRightClick && _activePointers == 0) {
      final pressDuration = now.difference(_rightClickDownTime);
      if (pressDuration < const Duration(milliseconds: 250) && !_hasMoved) {
        _performRightClick();
      }
      _potentialRightClick = false;
      return;
    }

    // Handle Left Click vs Drag
    if (_isDragging && _activePointers == 0) {
      final pressDuration = now.difference(_pointerDownTime);

      if (pressDuration < const Duration(milliseconds: 200) && !_hasMoved) {
        // Register as tap - fire mouse down then up
        _performLeftClick();
        _lastTapUpTime = now;
      }

      // Always end drag state
      _isDragging = false;
    }
  }

  void onPointerMove(PointerMoveEvent event) {
    if (_isEditing.value) return;

    // Handle single finger mouse movement (always follow finger)
    if (_activePointers == 1) {
      onTrackpadPan(event.delta);
    }

    // Handle trackpad panning/swipe with 2 fingers
    if (_activePointers == 2) {
      onTrackpadPan(event.delta);
    }

    // Detect significant movement for tap cancellation
    if (event.delta.distance > 2.0) {
      _hasMoved = true;
      // If we move significantly with 2 fingers, cancel right click
      if (_potentialRightClick) {
        _potentialRightClick = false;
      }
    }
  }

  void _performLeftClick() async {
    connectionController.sendMouseInput(dx: 0, dy: 0, buttons: 1);
    await Future.delayed(const Duration(milliseconds: 30));
    connectionController.sendMouseInput(dx: 0, dy: 0, buttons: 0);
  }

  void _performRightClick() async {
    // Right click is typically button 2 (binary 10) -> int 2?
    // Standard map: 1=Left, 2=Right, 4=Middle? Or 1=Left, 2=Middle, 3=Right?
    // In our UDP Service/HID:
    // Report: [Buttons]
    // HID standard: Bit 0 = Button 1 (Left), Bit 1 = Button 2 (Right), Bit 2 = Button 3 (Middle)
    // So Right Click = 2 (0b00000010)
    connectionController.sendMouseInput(dx: 0, dy: 0, buttons: 2);
    await Future.delayed(const Duration(milliseconds: 30));
    connectionController.sendMouseInput(dx: 0, dy: 0, buttons: 0);
  }

  void setTrackpadDragging(bool isDragging) {
    if (_isEditing.value) return;

    _mouseButtonState = isDragging ? 1 : 0;

    // Send immediate state update
    connectionController.sendMouseInput(
      dx: 0,
      dy: 0,
      buttons: _mouseButtonState,
    );
  }

  Future<void> saveLayout() async {
    if (_layout.value.id == 'xbox_default') {
      Get.snackbar(
        "Error",
        "Cannot modify default layout. Create a custom one.",
        backgroundColor: Colors.red.withValues(alpha: 0.5),
        colorText: Colors.white,
      );
      return;
    }
    await _storage.saveLayout(_layout.value);
    Get.snackbar(
      "Success",
      "Layout Saved",
      backgroundColor: Colors.green.withValues(alpha: 0.5),
      colorText: Colors.white,
    );
    _isEditing.value = false;
  }

  void selectControl(GamepadControl control) {
    _selectedControl.value = control;
    update(); // Trigger GetBuilder update to show selection UI
  }

  void updateControlSize(double newSize) {
    final control = _selectedControl.value;
    if (control == null) return;

    final ratio = control.width / control.height;
    if (control.width >= control.height) {
      control.width = newSize;
      control.height = newSize / ratio;
    } else {
      control.height = newSize;
      control.width = newSize * ratio;
    }
    _layout.refresh(); // Trigger Rx update
    update(); // Trigger GetBuilder update
  }

  void updateControlWidth(double newWidth) {
    final control = _selectedControl.value;
    if (control == null) return;
    control.width = newWidth;
    _layout.refresh(); // Trigger Rx update
    update(); // Trigger GetBuilder update
  }

  void updateControlHeight(double newHeight) {
    final control = _selectedControl.value;
    if (control == null) return;
    control.height = newHeight;
    _layout.refresh(); // Trigger Rx update
    update(); // Trigger GetBuilder update
  }

  Future<void> editControl(GamepadControl control) async {
    // Helper to pick a button
    Future<GamepadButton?> pickButton(
      GamepadButton? current,
      String label,
    ) async {
      return await Get.dialog<GamepadButton>(
        SimpleDialog(
          title: Text('Select Mapping for $label'),
          children: GamepadButton.values
              .map(
                (b) => SimpleDialogOption(
                  onPressed: () => Get.back(result: b),
                  child: Row(
                    children: [
                      if (b == current) const Icon(Icons.check, size: 16),
                      const SizedBox(width: 8),
                      Text(_descriptor.value.getButtonLabel(b)),
                      const Spacer(),
                      Text(
                        b.toString().split('.').last,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      );
    }

    // Helper to pick joystick
    Future<Joystick?> pickJoystick(Joystick? current) async {
      return await Get.dialog<Joystick>(
        SimpleDialog(
          title: const Text('Select Joystick'),
          children: Joystick.values
              .map(
                (j) => SimpleDialogOption(
                  onPressed: () => Get.back(result: j),
                  child: Text(j.toString().split('.').last.toUpperCase()),
                ),
              )
              .toList(),
        ),
      );
    }

    if (control.type == ControlType.button ||
        control.type == ControlType.shoulderButton) {
      final selected = await pickButton(control.buttonMapping, control.id);
      if (selected != null) {
        final index = _layout.value.controls.indexOf(control);
        if (index != -1) {
          _layout.value.controls[index] = control.copyWith(
            buttonMapping: selected,
          );
          _layout.refresh();
          update();
        }
      }
    } else if (control.type == ControlType.joystick) {
      final selected = await pickJoystick(control.joystickMapping);
      if (selected != null) {
        final index = _layout.value.controls.indexOf(control);
        if (index != -1) {
          _layout.value.controls[index] = control.copyWith(
            joystickMapping: selected,
          );
          _layout.refresh();
          update();
        }
      }
    } else if (control.type == ControlType.buttonCluster) {
      // Show dialog to pick which button to edit
      await Get.dialog(
        SimpleDialog(
          title: const Text('Configure Cluster'),
          children: [
            ListTile(
              title: const Text('Bottom Button (A)'),
              subtitle: Text(
                _descriptor.value.getButtonLabel(
                  control.clusterBottom ?? GamepadButton.button1,
                ),
              ),
              onTap: () async {
                Get.back();
                final b = await pickButton(
                  control.clusterBottom,
                  'Bottom Button',
                );
                if (b != null) {
                  final index = _layout.value.controls.indexOf(control);
                  if (index != -1) {
                    _layout.value.controls[index] = control.copyWith(
                      clusterBottom: b,
                    );
                    _layout.refresh();
                    update();
                  }
                }
              },
            ),
            ListTile(
              title: const Text('Right Button (B)'),
              subtitle: Text(
                _descriptor.value.getButtonLabel(
                  control.clusterRight ?? GamepadButton.button2,
                ),
              ),
              onTap: () async {
                Get.back();
                final b = await pickButton(
                  control.clusterRight,
                  'Right Button',
                );
                if (b != null) {
                  final index = _layout.value.controls.indexOf(control);
                  if (index != -1) {
                    _layout.value.controls[index] = control.copyWith(
                      clusterRight: b,
                    );
                    _layout.refresh();
                    update();
                  }
                }
              },
            ),
            ListTile(
              title: const Text('Left Button (X)'),
              subtitle: Text(
                _descriptor.value.getButtonLabel(
                  control.clusterLeft ?? GamepadButton.button3,
                ),
              ),
              onTap: () async {
                Get.back();
                final b = await pickButton(control.clusterLeft, 'Left Button');
                if (b != null) {
                  final index = _layout.value.controls.indexOf(control);
                  if (index != -1) {
                    _layout.value.controls[index] = control.copyWith(
                      clusterLeft: b,
                    );
                    _layout.refresh();
                    update();
                  }
                }
              },
            ),
            ListTile(
              title: const Text('Top Button (Y)'),
              subtitle: Text(
                _descriptor.value.getButtonLabel(
                  control.clusterTop ?? GamepadButton.button4,
                ),
              ),
              onTap: () async {
                Get.back();
                final b = await pickButton(control.clusterTop, 'Top Button');
                if (b != null) {
                  final index = _layout.value.controls.indexOf(control);
                  if (index != -1) {
                    _layout.value.controls[index] = control.copyWith(
                      clusterTop: b,
                    );
                    _layout.refresh();
                    update();
                  }
                }
              },
            ),
            ListTile(
              title: const Text('C Button'),
              subtitle: Text(
                _descriptor.value.getButtonLabel(
                  control.clusterC ?? GamepadButton.c,
                ),
              ),
              onTap: () async {
                Get.back();
                final b = await pickButton(control.clusterC, 'C Button');
                if (b != null) {
                  final index = _layout.value.controls.indexOf(control);
                  if (index != -1) {
                    _layout.value.controls[index] = control.copyWith(
                      clusterC: b,
                    );
                    _layout.refresh();
                    update();
                  }
                }
              },
            ),
            ListTile(
              title: const Text('Z Button'),
              subtitle: Text(
                _descriptor.value.getButtonLabel(
                  control.clusterZ ?? GamepadButton.z,
                ),
              ),
              onTap: () async {
                Get.back();
                final b = await pickButton(control.clusterZ, 'Z Button');
                if (b != null) {
                  final index = _layout.value.controls.indexOf(control);
                  if (index != -1) {
                    _layout.value.controls[index] = control.copyWith(
                      clusterZ: b,
                    );
                    _layout.refresh();
                    update();
                  }
                }
              },
            ),
          ],
        ),
      );
    }
  }

  void updateControlPosition(
    GamepadControl control,
    Offset delta,
    Size screenSize,
  ) {
    if (control.left != null) {
      control.left = control.left! + delta.dx;
      // Clamp to screen
      control.left = control.left!.clamp(0.0, screenSize.width - control.width);
    } else if (control.right != null) {
      control.right = control.right! - delta.dx;
      control.right = control.right!.clamp(
        0.0,
        screenSize.width - control.width,
      );
    }

    if (control.top != null) {
      control.top = control.top! + delta.dy;
      control.top = control.top!.clamp(0.0, screenSize.height - control.height);
    } else if (control.bottom != null) {
      control.bottom = control.bottom! - delta.dy;
      control.bottom = control.bottom!.clamp(
        0.0,
        screenSize.height - control.height,
      );
    }
    _layout.refresh(); // Trigger Rx update
    update(); // Trigger GetBuilder update
  }

  void clearSelectedControl() {
    _selectedControl.value = null;
    update(); // Trigger GetBuilder update to hide selection UI
  }

  void setDpad(int value) {
    _dpad.value = value;
    sendUpdate();
  }

  void resetDpad() {
    _dpad.value = 8;
    sendUpdate();
  }
}
