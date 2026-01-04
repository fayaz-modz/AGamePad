import 'dart:math';
import 'package:flutter/material.dart';
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
      final size = min(width, height);
      
      // Use fractional positions so everything scales proportionally
      final has6Buttons = buttonC != null;
      
      // Button size as fraction of container - reduced to prevent clipping with increased spacing
      final btnSizeFraction = has6Buttons ? 0.32 : 0.35;
      final btnSize = size * btnSizeFraction;
      
      // Calculate spacing for cluster formation - push out from center
      final spacing = has6Buttons ? btnSize * 0.75 : btnSize * 0.85;
      
      // Center point of the container
      final centerX = width / 2;
      final centerY = height / 2;
      
      // Offset for 6-button layout to shift the main 4 buttons left
      final clusterOffsetX = has6Buttons ? -size * 0.12 : 0.0;
      
      return Stack(
        children: [
          // Button 1 (Bottom) - centered horizontally, below center
          Positioned(
            left: centerX + clusterOffsetX - btnSize / 2,
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
            left: centerX + spacing + clusterOffsetX - btnSize / 2,
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
            left: centerX - spacing + clusterOffsetX - btnSize / 2,
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
            left: centerX + clusterOffsetX - btnSize / 2,
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
              left: centerX + spacing * 1.8 - btnSize / 2,
              top: centerY + spacing * 0.5 - btnSize / 2,
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
              left: centerX + spacing * 1.8 - btnSize / 2,
              top: centerY - spacing * 0.5 - btnSize / 2,
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
  final Color color;
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
        widget.onDown(widget.button);  // Send input first for lowest latency
        setState(() => _isPressed = true);
      },
      onPointerUp: (_) {
        widget.onUp(widget.button);  // Send input first for lowest latency
        setState(() => _isPressed = false);
      },
      onPointerCancel: (_) {
        widget.onUp(widget.button);  // Send input first for lowest latency
        setState(() => _isPressed = false);
      },

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isPressed
              ? widget.color.withValues(alpha: 1.0)
              : widget.color.withValues(alpha: 0.6),
          border: Border.all(
            color: _isPressed ? Colors.white : Colors.white70,
            width: _isPressed ? 4 : 2
          ),
          boxShadow: _isPressed
              ? [BoxShadow(color: widget.color.withValues(alpha: 0.8), blurRadius: 15, spreadRadius: 2)]
              : [],
        ),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: widget.size * 0.4,
              color: Colors.white,
              shadows: [Shadow(blurRadius: 2, color: Colors.black)]
            )
          ),
        ),
      ),
    );
  }
}
