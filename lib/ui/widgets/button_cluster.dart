import 'dart:math';
import 'package:flutter/material.dart';
import 'package:agamepad/ui/widgets/inner_shadow_painter.dart';
import '../../models/gamepad_descriptor.dart';

class ButtonCluster extends StatelessWidget {
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
    required this.onUp,
    this.buttonBottom = GamepadButton.button1,
    this.buttonRight = GamepadButton.button2,
    this.buttonLeft = GamepadButton.button3,
    this.buttonTop = GamepadButton.button4,
    this.buttonC,
    this.buttonZ,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
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
    });
  }
}

class _RoundButton extends StatefulWidget {
  final String label;
  final Color color; // Kept for API compatibility but not used
  final GamepadButton button;
  final void Function(GamepadButton) onDown;
  final void Function(GamepadButton) onUp;
  final double size;

  const _RoundButton(this.label, this.color, this.button, this.onDown, this.onUp, this.size);

  @override
  State<_RoundButton> createState() => _RoundButtonState();
}

class _RoundButtonState extends State<_RoundButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
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
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: _isPressed ? 0.25 : 0.15),
        ),
        child: CustomPaint(
          painter: InnerShadowPainter(
            shape: BoxShape.circle,
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
            child: Text(
              widget.label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: widget.size * 0.4,
                color: Colors.white.withValues(alpha: 0.9),
              )
            ),
          ),
        ),
      ),
    );
  }
}
