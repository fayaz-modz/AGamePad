import 'dart:math';
import 'package:flutter/material.dart';
import 'package:agamepad/ui/widgets/inner_shadow_painter.dart';

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

  Widget? _cachedBackground;
  Widget? _cachedKnob;
  double? _cachedSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Enforce square aspect ratio for the joystick area
        final actualSize = min(constraints.maxWidth, constraints.maxHeight);
        final knobSize = actualSize / 2.0; // Increased from 2.5 to 2.0 for bigger knob

        // Rebuild cached widgets only if size changes
        if (actualSize != _cachedSize) {
          _cachedSize = actualSize;

          _cachedBackground = Container(
            width: actualSize,
            height: actualSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            child: CustomPaint(
              painter: InnerShadowPainter(
                shape: BoxShape.circle,
                shadows: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 6,
                    offset: const Offset(3, 3),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
            ),
          );

          _cachedKnob = Container(
            width: knobSize,
            height: knobSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            child: CustomPaint(
              painter: InnerShadowPainter(
                shape: BoxShape.circle,
                shadows: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 3,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
            ),
          );
        }

        return Center(
          child: SizedBox(
            width: actualSize,
            height: actualSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Static Background with Shadows
                _cachedBackground!,

                // Interactive Layer
                Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (event) {
                    if (_activePointerId == null) {
                      _activePointerId = event.pointer;
                      _updatePosition(event.localPosition, actualSize);
                    }
                  },
                  onPointerMove: (event) {
                    if (_activePointerId == event.pointer) {
                      _updatePosition(event.localPosition, actualSize);
                    }
                  },
                  onPointerUp: (event) {
                    if (_activePointerId == event.pointer) {
                      _activePointerId = null;
                      _reset();
                    }
                  },
                  onPointerCancel: (event) {
                    if (_activePointerId == event.pointer) {
                      _activePointerId = null;
                      _reset();
                    }
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Knob
                      Positioned(
                        left: (actualSize / 2) +
                            (_alignment.x * (actualSize / 2)) -
                            (knobSize / 2),
                        top: (actualSize / 2) +
                            (_alignment.y * (actualSize / 2)) -
                            (knobSize / 2),
                        child: _cachedKnob!,
                      ),
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
