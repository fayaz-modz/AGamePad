import 'dart:math';
import 'package:flutter/material.dart';
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
    final isLeftShoulder = widget.type == ShoulderButtonType.l1 || 
                           widget.type == ShoulderButtonType.l2;
    final rotation = isLeftShoulder ? -45.0 : 45.0; // -45 for left, 45 for right
    
    // Determine if this is a top button (L1/R1) or bottom button (L2/R2)
    final isTopButton = widget.type == ShoulderButtonType.l1 || 
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 50),
          decoration: BoxDecoration(
            // Custom border radius - only one side circular, base is flat with small corners
            borderRadius: isTopButton
                ? const BorderRadius.only(
                    topLeft: Radius.circular(100), // Top circular
                    topRight: Radius.circular(100),
                    bottomLeft: Radius.circular(16), // Bottom flat with rounded corners
                    bottomRight: Radius.circular(16),
                  )
                : const BorderRadius.only(
                    bottomLeft: Radius.circular(100), // Bottom circular
                    bottomRight: Radius.circular(100),
                    topLeft: Radius.circular(16), // Top flat with rounded corners
                    topRight: Radius.circular(16),
                  ),
            color: _isPressed
                ? Colors.blueAccent.withValues(alpha: 0.5)
                : Colors.grey[800],
            border: Border.all(
              color: _isPressed ? Colors.blueAccent : Colors.white54,
              width: _isPressed ? 2 : 1,
            ),
            boxShadow: _isPressed
                ? [
                    BoxShadow(
                      color: Colors.blueAccent.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Transform.rotate(
              angle: -rotation * pi / 180, // Counter-rotate the text
              alignment: Alignment.center,
              child: Text(
                widget.label,
                style: TextStyle(
                  color: _isPressed ? Colors.white : Colors.white,
                  fontWeight: _isPressed ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
