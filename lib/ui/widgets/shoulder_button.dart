import 'dart:math';
import 'package:flutter/material.dart';
import 'package:agamepad/ui/widgets/inner_shadow_painter.dart';
import '../../models/gamepad_descriptor.dart';

enum ShoulderButtonType {
  l1, // Top shoulder, rotated -45deg, top circular, bottom 50%
  l2, // Bottom shoulder, rotated 45deg, bottom circular, top 50%
  r1, // Top shoulder, rotated -45deg, top circular, bottom 50%
  r2, // Bottom shoulder, rotated 45deg, bottom circular, top 50%
}

class ShoulderButton extends StatefulWidget {
  final String label;
  final GamepadButton button;
  final ShoulderButtonType type;
  final void Function(GamepadButton) onDown;
  final void Function(GamepadButton) onUp;

  const ShoulderButton({
    super.key,
    required this.label,
    required this.button,
    required this.type,
    required this.onDown,
    required this.onUp,
  });

  @override
  State<ShoulderButton> createState() => _ShoulderButtonState();
}

class _ShoulderButtonState extends State<ShoulderButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Determine rotation angle based on left/right side
    final isLeftShoulder =
        widget.type == ShoulderButtonType.l1 ||
        widget.type == ShoulderButtonType.l2;
    final rotation = isLeftShoulder
        ? -45.0
        : 45.0; // -45 for left, 45 for right

    // Determine if this is a top button (L1/R1) or bottom button (L2/R2)
    final isTopButton =
        widget.type == ShoulderButtonType.l1 ||
        widget.type == ShoulderButtonType.r1;

    return Transform.rotate(
      angle: rotation * pi / 180, // Convert degrees to radians
      alignment: Alignment.center, // Rotate around center
      child: Listener(
        onPointerDown: (_) {
          widget.onDown(widget.button);
          setState(() => _isPressed = true);
        },
        onPointerUp: (_) {
          widget.onUp(widget.button);
          setState(() => _isPressed = false);
        },
        onPointerCancel: (_) {
          widget.onUp(widget.button);
          setState(() => _isPressed = false);
        },
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
            color: Colors.white.withValues(alpha: _isPressed ? 0.25 : 0.15),
          ),
          child: CustomPaint(
            painter: InnerShadowPainter(
              shape: BoxShape.rectangle,
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
              shadows: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: _isPressed ? 0.3 : 0.2), // Reduced opacity
                  blurRadius: 15,
                  spreadRadius: 6,
                  offset: const Offset(3, 3),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: _isPressed ? 0.15 : 0.1), // Reduced opacity
                  blurRadius: 8,
                  spreadRadius: 2,
                  offset: const Offset(1, 1),
                ),
              ],
            ),
            child: Center(
              child: Transform.rotate(
                angle: -rotation * pi / 180,
                alignment: Alignment.center,
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: _isPressed
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
