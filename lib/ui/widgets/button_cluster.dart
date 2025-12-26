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
      final s = min(constraints.maxWidth, constraints.maxHeight);
      final btnSize = s * (buttonC != null ? 0.30 : 0.35);

      final offsetX = (constraints.maxWidth - s) / 2;
      final offsetY = (constraints.maxHeight - s) / 2;

      return Stack(
        children: [
          // Button 1 (Bottom)
          Positioned(
            bottom: offsetY + (buttonC != null ? s * 0.1 : 0),
            left: offsetX + (s - btnSize) / 2 - (buttonC != null ? s * 0.15 : 0),
            child: _RoundButton(
              descriptor.getButtonLabel(buttonBottom),
              Colors.green,
              buttonBottom,
              onDown,
              onUp,
              btnSize,
            ),
          ),
          // Button 2 (Right)
          Positioned(
            right: offsetX + (buttonC != null ? s * 0.3 : 0),
            top: offsetY + (s - btnSize) / 2,
            child: _RoundButton(
              descriptor.getButtonLabel(buttonRight),
              Colors.red,
              buttonRight,
              onDown,
              onUp,
              btnSize,
            ),
          ),
          // Button 3 (Left)
          Positioned(
            left: offsetX + (buttonC != null ? 0 : 0),
            top: offsetY + (s - btnSize) / 2,
            child: _RoundButton(
              descriptor.getButtonLabel(buttonLeft),
              Colors.blue,
              buttonLeft,
              onDown,
              onUp,
              btnSize,
            ),
          ),
          // Button 4 (Top)
          Positioned(
            top: offsetY + (buttonC != null ? s * 0.1 : 0),
            left: offsetX + (s - btnSize) / 2 - (buttonC != null ? s * 0.15 : 0),
            child: _RoundButton(
              descriptor.getButtonLabel(buttonTop),
              Colors.amber,
              buttonTop,
              onDown,
              onUp,
              btnSize,
            ),
          ),
          
          if (buttonC != null)
            Positioned(
              right: offsetX,
              bottom: offsetY + s * 0.1,
              child: _RoundButton(
                descriptor.getButtonLabel(buttonC!),
                Colors.purple,
                buttonC!,
                onDown,
                onUp,
                btnSize,
              ),
            ),
          if (buttonZ != null)
            Positioned(
              right: offsetX,
              top: offsetY + s * 0.1,
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
        setState(() => _isPressed = true);
        widget.onDown(widget.button);
      },
      onPointerUp: (_) {
        setState(() => _isPressed = false);
        widget.onUp(widget.button);
      },
      onPointerCancel: (_) {
        setState(() => _isPressed = false);
        widget.onUp(widget.button);
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
