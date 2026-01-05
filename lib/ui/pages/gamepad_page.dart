import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/gamepad_layout.dart';
import '../../models/gamepad_descriptor.dart';
import '../../services/layout_storage_service.dart';
import '../../providers/connection_provider.dart';
import '../widgets/virtual_joystick.dart';
import '../widgets/circular_dpad.dart';
import '../widgets/button_cluster.dart';
import '../widgets/trackpad_widget.dart';
import '../widgets/shoulder_button.dart';
import '../widgets/inner_shadow_painter.dart';

class GamepadPage extends StatefulWidget {
  const GamepadPage({super.key});

  @override
  State<GamepadPage> createState() => _GamepadPageState();
}

class _GamepadPageState extends State<GamepadPage> {
  final LayoutStorageService _storage = LayoutStorageService();
  ConnectionProvider? _connectionProvider;

  late GamepadLayout _layout;
  late GamepadDescriptor _descriptor;
  late ButtonMaskBuilder _buttonMask;

  bool _isEditing = false;
  GamepadControl? _selectedControl;

  // State for Inputs
  int _lx = 127;
  int _ly = 127;
  int _rx = 127;
  int _ry = 127;
  int _l2 = 0;
  int _r2 = 0;
  int _dpad = 8;

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

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Initialize connection provider after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectionProvider = Provider.of<ConnectionProvider>(
        context,
        listen: false,
      );
      _loadLayout();
    });
  }

  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   if (_connectionProvider == null) {
  //     _connectionProvider = Provider.of<ConnectionProvider>(
  //       context,
  //       listen: false,
  //     );
  //     if (_isInit == false) {
  //       _loadLayout();
  //     }
  //   }
  // }

  @override
  void dispose() {
    _connectionProvider?.stopKeepalive();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // @override
  // void reassemble() {
  //   super.reassemble();
  //   // Reload layout on hot reload - for default layouts, reload from source
  //   if (_isInit) {
  //     setState(() {
  //       if (_layout.id == 'xbox_default') {
  //         _layout = GamepadLayout.xbox();
  //       } else if (_layout.id == 'android_default') {
  //         _layout = GamepadLayout.android();
  //       }
  //       // Custom layouts will keep their current state
  //     });
  //   }
  // }

  void _loadLayout() async {
    final args = ModalRoute.of(context)!.settings.arguments;

    // Handle both old format (just layout) and new format (map with layout and editMode)
    if (args is GamepadLayout) {
      _layout = args;
      _isEditing = false;
    } else if (args is Map) {
      _layout = args['layout'] as GamepadLayout;
      _isEditing = args['editMode'] as bool? ?? false;
    } else {
      // Default layout
      final layouts = await _storage.loadLayouts();
      _layout = layouts.isNotEmpty ? layouts.first : GamepadLayout.xbox();
      _isEditing = false;
    }

    // Initialize descriptor and button mask
    _descriptor = GamepadDescriptor();
    _buttonMask = ButtonMaskBuilder(_descriptor);

    // Start keepalive for connections
    _connectionProvider?.startKeepalive();

    setState(() {
      // _isInit = true;
    });
  }

  void _sendUpdate() {
    if (_isEditing) return;

    // If a send is already scheduled, skip (batching)
    if (_sendScheduled) return;

    _sendScheduled = true;

    // Use scheduleMicrotask to batch multiple rapid calls into one send
    scheduleMicrotask(() {
      _sendScheduled = false;

      final currentButtons = _buttonMask.mask;

      // Only send if state has actually changed to minimize latency and overhead
      if (currentButtons == _lastButtons &&
          _lx == _lastLx &&
          _ly == _lastLy &&
          _rx == _lastRx &&
          _ry == _lastRy &&
          _l2 == _lastL2 &&
          _r2 == _lastR2 &&
          _dpad == _lastDpad) {
        return;
      }

      _lastButtons = currentButtons;
      _lastLx = _lx;
      _lastLy = _ly;
      _lastRx = _rx;
      _lastRy = _ry;
      _lastL2 = _l2;
      _lastR2 = _r2;
      _lastDpad = _dpad;

      _connectionProvider?.sendGamepadInput(
        buttons: currentButtons,
        lx: _lx,
        ly: _ly,
        rx: _rx,
        ry: _ry,
        l2: _l2,
        r2: _r2,
        dpad: _dpad,
      );
    });
  }

  void _onButtonDown(GamepadButton button) {
    if (_isEditing) return;
    _buttonMask.press(button);
    if (button == GamepadButton.l2) _l2 = 255;
    if (button == GamepadButton.r2) _r2 = 255;
    _sendUpdate();
  }

  void _onButtonUp(GamepadButton button) {
    if (_isEditing) return;
    _buttonMask.release(button);
    if (button == GamepadButton.l2) _l2 = 0;
    if (button == GamepadButton.r2) _r2 = 0;
    _sendUpdate();
  }

  void _onJoystickChange(Joystick joystick, Offset value) {
    if (_isEditing) return;
    int map(double v) => ((v + 1.0) * 127.5).toInt().clamp(0, 255);

    // mapping 0 = Left Stick, 1 = Right Stick
    if (joystick == Joystick.left) {
      _lx = map(value.dx);
      _ly = map(value.dy);
    } else {
      _rx = map(value.dx);
      _ry = map(value.dy);
    }
    _sendUpdate();
  }

  Future<void> _saveLayout() async {
    if (_layout.id == 'xbox_default') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cannot modify default layout. Create a custom one."),
        ),
      );
      return;
    }
    await _storage.saveLayout(_layout);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Layout Saved")));
      setState(() {
        _isEditing = false;
      });
    }
  }

  void _selectControl(GamepadControl control) {
    setState(() {
      _selectedControl = control;
    });
  }

  void _updateControlSize(double newSize) {
    if (_selectedControl == null) return;

    setState(() {
      final control = _selectedControl!;

      // TODO: Reimplement with edge-based positioning
      // For now, just update size
      final ratio = control.width / control.height;
      if (control.width >= control.height) {
        control.width = newSize;
        control.height = newSize / ratio;
      } else {
        control.height = newSize;
        control.width = newSize * ratio;
      }
    });
  }

  void _updateControlWidth(double newWidth) {
    if (_selectedControl == null) return;
    setState(() {
      final control = _selectedControl!;
      control.width = newWidth;
      // TODO: Adjust left/right position if needed
    });
  }

  void _updateControlHeight(double newHeight) {
    if (_selectedControl == null) return;
    setState(() {
      final control = _selectedControl!;
      control.height = newHeight;
      // TODO: Adjust top/bottom position if needed
    });
  }

  Future<void> _editControl(GamepadControl control) async {
    // Helper to pick a button
    Future<GamepadButton?> pickButton(
      GamepadButton? current,
      String label,
    ) async {
      return await showDialog<GamepadButton>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text('Select Mapping for $label'),
          children: GamepadButton.values
              .map(
                (b) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, b),
                  child: Row(
                    children: [
                      if (b == current) const Icon(Icons.check, size: 16),
                      const SizedBox(width: 8),
                      Text(_descriptor.getButtonLabel(b)),
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
      return await showDialog<Joystick>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Select Joystick'),
          children: Joystick.values
              .map(
                (j) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, j),
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
        setState(() {
          // We can't modify final fields of GamepadControl directly nicely without rebuilding the list or making them mutable.
          // Since we are in a mutable state management flow, let's just cheat and assume GamepadControl fields are mutable for this "Edit Mode"
          // OR (better) replace the control in the list.
          // However GamepadControl fields are final in my previous read. Let's check.
          // Ah, in GamepadLayout.dart they are final except x,y.
          // I need to replace the control object.
          final index = _layout.controls.indexOf(control);
          if (index != -1) {
            _layout.controls[index] = control.copyWith(buttonMapping: selected);
          }
        });
      }
    } else if (control.type == ControlType.joystick) {
      final selected = await pickJoystick(control.joystickMapping);
      if (selected != null) {
        setState(() {
          final index = _layout.controls.indexOf(control);
          if (index != -1) {
            _layout.controls[index] = control.copyWith(
              joystickMapping: selected,
            );
          }
        });
      }
    } else if (control.type == ControlType.buttonCluster) {
      // Show dialog to pick which button to edit
      await showDialog(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Configure Cluster'),
          children: [
            ListTile(
              title: const Text('Bottom Button (A)'),
              subtitle: Text(
                _descriptor.getButtonLabel(
                  control.clusterBottom ?? GamepadButton.button1,
                ),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final b = await pickButton(
                  control.clusterBottom,
                  'Bottom Button',
                );
                if (b != null) {
                  setState(() {
                    final index = _layout.controls.indexOf(control);
                    if (index != -1) {
                      _layout.controls[index] = control.copyWith(
                        clusterBottom: b,
                      );
                    }
                  });
                }
              },
            ),
            ListTile(
              title: const Text('Right Button (B)'),
              subtitle: Text(
                _descriptor.getButtonLabel(
                  control.clusterRight ?? GamepadButton.button2,
                ),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final b = await pickButton(
                  control.clusterRight,
                  'Right Button',
                );
                if (b != null) {
                  setState(() {
                    final index = _layout.controls.indexOf(control);
                    if (index != -1) {
                      _layout.controls[index] = control.copyWith(
                        clusterRight: b,
                      );
                    }
                  });
                }
              },
            ),
            ListTile(
              title: const Text('Left Button (X)'),
              subtitle: Text(
                _descriptor.getButtonLabel(
                  control.clusterLeft ?? GamepadButton.button3,
                ),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final b = await pickButton(control.clusterLeft, 'Left Button');
                if (b != null) {
                  setState(() {
                    final index = _layout.controls.indexOf(control);
                    if (index != -1) {
                      _layout.controls[index] = control.copyWith(
                        clusterLeft: b,
                      );
                    }
                  });
                }
              },
            ),
            ListTile(
              title: const Text('Top Button (Y)'),
              subtitle: Text(
                _descriptor.getButtonLabel(
                  control.clusterTop ?? GamepadButton.button4,
                ),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final b = await pickButton(control.clusterTop, 'Top Button');
                if (b != null) {
                  setState(() {
                    final index = _layout.controls.indexOf(control);
                    if (index != -1) {
                      _layout.controls[index] = control.copyWith(clusterTop: b);
                    }
                  });
                }
              },
            ),
            ListTile(
              title: const Text('C Button'),
              subtitle: Text(
                _descriptor.getButtonLabel(control.clusterC ?? GamepadButton.c),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final b = await pickButton(control.clusterC, 'C Button');
                if (b != null) {
                  setState(() {
                    final index = _layout.controls.indexOf(control);
                    if (index != -1) {
                      _layout.controls[index] = control.copyWith(clusterC: b);
                    }
                  });
                }
              },
            ),
            ListTile(
              title: const Text('Z Button'),
              subtitle: Text(
                _descriptor.getButtonLabel(control.clusterZ ?? GamepadButton.z),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final b = await pickButton(control.clusterZ, 'Z Button');
                if (b != null) {
                  setState(() {
                    final index = _layout.controls.indexOf(control);
                    if (index != -1) {
                      _layout.controls[index] = control.copyWith(clusterZ: b);
                    }
                  });
                }
              },
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Stack(
        clipBehavior: Clip.none, // Allow controls to overflow without clipping
        children: [
          // Render all controls from layout
          ..._layout.controls.map(
            (control) => _buildControl(context, control, size),
          ),

          // Edit Toolkit - only show if in edit mode
          if (_isEditing) ...[
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.save, color: Colors.green),
                    onPressed: _saveLayout,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      Navigator.pop(context);
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
            if (_selectedControl != null)
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
                              "Editing: ${_selectedControl!.getLabel(_descriptor)}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (_selectedControl!.type == ControlType.dpad ||
                                _selectedControl!.type ==
                                    ControlType.buttonCluster ||
                                _selectedControl!.type == ControlType.joystick)
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
                                        thumbShape: const RoundSliderThumbShape(
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
                                          _selectedControl!.width,
                                          _selectedControl!.height,
                                        ),
                                        min: 0.05,
                                        max: 0.5,
                                        activeColor: Colors.blueAccent,
                                        onChanged: _updateControlSize,
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
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                              overlayRadius: 12,
                                            ),
                                        trackHeight: 2,
                                      ),
                                      child: Slider(
                                        value: _selectedControl!.width.clamp(
                                          0.05,
                                          0.8,
                                        ),
                                        min: 0.05,
                                        max: 0.8,
                                        activeColor: Colors.blueAccent,
                                        onChanged: _updateControlWidth,
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
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                              overlayRadius: 12,
                                            ),
                                        trackHeight: 2,
                                      ),
                                      child: Slider(
                                        value: _selectedControl!.height.clamp(
                                          0.05,
                                          0.8,
                                        ),
                                        min: 0.05,
                                        max: 0.8,
                                        activeColor: Colors.blueAccent,
                                        onChanged: _updateControlHeight,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                TextButton.icon(
                                  onPressed: () =>
                                      _editControl(_selectedControl!),
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
                                      setState(() => _selectedControl = null),
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
  }

  Widget _buildControl(
    BuildContext context,
    GamepadControl control,
    Size screenSize,
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

    Widget child = _renderWidgetForControl(control);

    // Highlight if selected
    if (_isEditing && _selectedControl == control) {
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

    if (_isEditing) {
      return Positioned(
        left: left,
        top: top,
        width: actualWidth,
        height: actualHeight,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              // Update edge positions based on drag delta
              if (control.left != null) {
                control.left = control.left! + details.delta.dx;
                // Clamp to screen
                control.left = control.left!.clamp(
                  0.0,
                  screenSize.width - width,
                );
              } else if (control.right != null) {
                control.right = control.right! - details.delta.dx;
                control.right = control.right!.clamp(
                  0.0,
                  screenSize.width - width,
                );
              }

              if (control.top != null) {
                control.top = control.top! + details.delta.dy;
                control.top = control.top!.clamp(
                  0.0,
                  screenSize.height - height,
                );
              } else if (control.bottom != null) {
                control.bottom = control.bottom! - details.delta.dy;
                control.bottom = control.bottom!.clamp(
                  0.0,
                  screenSize.height - height,
                );
              }
            });
          },
          onTap: () => _selectControl(control),
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

  Widget _renderWidgetForControl(GamepadControl control) {
    switch (control.type) {
      case ControlType.joystick:
        return VirtualJoystick(
          onChanged: (val) =>
              _onJoystickChange(control.joystickMapping ?? Joystick.left, val),
        );
      case ControlType.dpad:
        return CircularDPad(
          onDown: (val) {
            _dpad = val;
            _sendUpdate();
          },
          onUp: () {
            _dpad = 8;
            _sendUpdate();
          },
        );
      case ControlType.buttonCluster:
        return ButtonCluster(
          descriptor: _descriptor,
          onDown: _onButtonDown,
          onUp: _onButtonUp,
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
          label: control.getLabel(_descriptor),
          button: button,
          type: shoulderType,
          onDown: _onButtonDown,
          onUp: _onButtonUp,
        );
      case ControlType.button:
        return _OptionButton(
          label: control.getLabel(_descriptor),
          onDown: () =>
              _onButtonDown(control.buttonMapping ?? GamepadButton.select),
          onUp: () =>
              _onButtonUp(control.buttonMapping ?? GamepadButton.select),
        );
      case ControlType.trackpad:
        return TrackpadWidget(
          label: control.getLabel(_descriptor),
          onPointerReport: (dx, dy, buttons) {
            if (_isEditing) return;
            _connectionProvider?.sendMouseInput(
              dx: dx,
              dy: dy,
              buttons: buttons,
            );
          },
        );
    }
  }
}

class _OptionButton extends StatefulWidget {
  final String label;
  final VoidCallback onDown;
  final VoidCallback onUp;

  const _OptionButton({
    required this.label,
    required this.onDown,
    required this.onUp,
  });

  @override
  State<_OptionButton> createState() => _OptionButtonState();
}

class _OptionButtonState extends State<_OptionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        widget.onDown();
        setState(() => _isPressed = true);
      },
      onPointerUp: (_) {
        widget.onUp();
        setState(() => _isPressed = false);
      },
      onPointerCancel: (_) {
        widget.onUp();
        setState(() => _isPressed = false);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white.withValues(alpha: _isPressed ? 0.25 : 0.15),
        ),
        child: CustomPaint(
          painter: InnerShadowPainter(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(8),
            shadows: [
              BoxShadow(
                color: Colors.white.withValues(
                  alpha: _isPressed ? 0.3 : 0.2,
                ), // Reduced opacity
                blurRadius: 15,
                spreadRadius: 6,
                offset: const Offset(3, 3),
              ),
              BoxShadow(
                color: Colors.white.withValues(
                  alpha: _isPressed ? 0.15 : 0.1,
                ), // Reduced opacity
                blurRadius: 8,
                spreadRadius: 2,
                offset: const Offset(1, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
