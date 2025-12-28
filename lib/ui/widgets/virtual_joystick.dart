import 'dart:math';
import 'package:flutter/material.dart';

class VirtualJoystick extends StatefulWidget {
  final ValueChanged<Offset> onChanged;

  const VirtualJoystick({
    super.key,
    required this.onChanged,
  });

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Alignment _alignment = Alignment.center;
  int? _activePointerId; // Track which pointer is controlling this joystick

  void _updatePosition(Offset localPosition, double size) {
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

    setState(() {
      _alignment = Alignment(nx, ny);
    });

    widget.onChanged(Offset(nx.clamp(-1.0, 1.0), ny.clamp(-1.0, 1.0)));
  }

  void _reset() {
    setState(() {
      _alignment = Alignment.center;
    });
    widget.onChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Enforce square aspect ratio for the joystick area
        final actualSize = min(constraints.maxWidth, constraints.maxHeight);
        final knobSize = actualSize / 2.5;

        return Center(
          child: Container(
            width: actualSize,
            height: actualSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
              border: Border.all(color: Colors.white30),
            ),
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                // Only accept if we don't have an active pointer
                if (_activePointerId == null) {
                  _activePointerId = event.pointer;
                  _updatePosition(event.localPosition, actualSize);
                }
              },
              onPointerMove: (event) {
                // Only respond to our tracked pointer
                if (_activePointerId == event.pointer) {
                  _updatePosition(event.localPosition, actualSize);
                }
              },
              onPointerUp: (event) {
                // Only reset if it's our tracked pointer
                if (_activePointerId == event.pointer) {
                  _activePointerId = null;
                  _reset();
                }
              },
              onPointerCancel: (event) {
                // Only reset if it's our tracked pointer
                if (_activePointerId == event.pointer) {
                  _activePointerId = null;
                  _reset();
                }
              },
              child: Align(
                alignment: _alignment,
                child: Container(
                  width: knobSize,
                  height: knobSize,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    );
  }
}
