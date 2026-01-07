import 'dart:math';

import 'package:agamepad/app/components/inner_shadow.dart';
import 'package:agamepad/app/controllers/gamepad_theme_controller.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';

class DpadController extends GetxController {
  final ValueChanged<int> onDown;
  final VoidCallback onUp;
  final double size;

  DpadController({
    required this.size,
    required this.onUp,
    required this.onDown,
  });

  var currentValue = 8.obs; // 8 = Center/Neutral (not 0 which is Up!)

  bool get isActive => currentValue.value != 8;

  // Map current value to active visual sectors for the painter
  Set<int> get activeVisualSectors {
    final s = <int>{};
    if (currentValue.value == 8) return s; // 8 is Center/Null

    // 0=Up, 1=UpRight, 2=Right, 3=DownRight, 4=Down, 5=DownLeft, 6=Left, 7=UpLeft
    if ([0, 1, 7].contains(currentValue.value)) s.add(0); // Up
    if ([2, 1, 3].contains(currentValue.value)) s.add(2); // Right
    if ([4, 3, 5].contains(currentValue.value)) s.add(4); // Down
    if ([6, 5, 7].contains(currentValue.value)) s.add(6); // Left
    return s;
  }

  // Cache paths to avoid parsing SVG on every paint
  final DPadPaths paths = DPadPaths();

  @override
  void onInit() {
    super.onInit();
    paths.update(size);
  }

  void handleUp() {
    if (currentValue.value != 8) {
      currentValue.value = 8;
      onUp();
    }
  }

  void handleInput(Offset localPosition) {
    // Calculate center and use consistent radius for normalization
    final centerX = size / 2;
    final centerY = size / 2;
    final radius = size / 2;

    // Calculate normalized x, y coordinates from center (-1 to +1 range)
    final dx = localPosition.dx - centerX;
    final dy = localPosition.dy - centerY;
    final x = dx / radius;
    final y = dy / radius;

    // Deadzone check (circular, 10% of radius)
    final distance = sqrt(x * x + y * y);
    if (distance < 0.10) {
      handleUp();
      return;
    }

    // Simple threshold-based direction detection
    // Higher thresholds prevent accidental diagonal activation
    // Cardinal directions (up/down/left/right) are strongly preferred
    const cardinalThreshold = 0.25; // Threshold for single-axis activation
    const diagonalThreshold = 0.55; // Both axes must exceed this for diagonal

    // For diagonals, require both x and y to be strongly in that direction
    final absX = x.abs();
    final absY = y.abs();

    // Only trigger diagonal if BOTH axes are strongly activated
    final allowDiagonal = absX > diagonalThreshold && absY > diagonalThreshold;

    final isUp = y < -cardinalThreshold;
    final isDown = y > cardinalThreshold;
    final isLeft = x < -cardinalThreshold;
    final isRight = x > cardinalThreshold;

    // Map to D-pad value (0-8 hat switch standard)
    // 0=Up, 1=UpRight, 2=Right, 3=DownRight, 4=Down, 5=DownLeft, 6=Left, 7=UpLeft, 8=Center
    int dpadValue = 8;

    if (allowDiagonal && isUp && isRight) {
      dpadValue = 1;
    } else if (allowDiagonal && isDown && isRight) {
      dpadValue = 3;
    } else if (allowDiagonal && isDown && isLeft) {
      dpadValue = 5;
    } else if (allowDiagonal && isUp && isLeft) {
      dpadValue = 7;
    } else if (isUp && absY > absX) {
      // Prefer the dominant axis for cardinal directions
      dpadValue = 0;
    } else if (isDown && absY > absX) {
      dpadValue = 4;
    } else if (isRight && absX > absY) {
      dpadValue = 2;
    } else if (isLeft && absX > absY) {
      dpadValue = 6;
    } else if (isUp) {
      dpadValue = 0;
    } else if (isRight) {
      dpadValue = 2;
    } else if (isDown) {
      dpadValue = 4;
    } else if (isLeft) {
      dpadValue = 6;
    }

    // Update state and send event when direction changes
    if (currentValue.value != dpadValue) {
      currentValue.value = dpadValue;

      // Send onDown event for any new direction (including fast taps)
      if (dpadValue != 8) {
        onDown(dpadValue);
      }
    }
  }
}

class Dpad extends StatelessWidget {
  final ValueChanged<int> onDown;
  final VoidCallback onUp;
  final double size;

  const Dpad({
    super.key,
    required this.onUp,
    required this.onDown,
    this.size = 150.0,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DpadController>(
      init: DpadController(size: size, onUp: onUp, onDown: onDown),
      builder: (controller) => SizedBox.square(
        dimension: controller.size,
        child: Listener(
          onPointerDown: (event) => controller.handleInput(event.localPosition),
          onPointerMove: (event) => controller.handleInput(event.localPosition),
          onPointerUp: (_) => controller.handleUp(),
          onPointerCancel: (_) => controller.handleUp(),
          child: Obx(
            () => CustomPaint(
              painter: _DPadPainter(
                activeSectors: controller.activeVisualSectors,
                paths: controller.paths,
                controller: controller,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DPadPaths {
  final Path rightPath = Path();
  final Path upPath = Path();
  final Path downPath = Path();
  final Path leftPath = Path();

  void update(double size) {
    final center = Offset(size / 2, size / 2);
    final scale = size / 256;

    rightPath.reset();
    upPath.reset();
    downPath.reset();
    leftPath.reset();

    _createPathFromSVGData(
      rightPath,
      "M176.682 92.4564C180.085 89.0376 184.701 87.1169 189.514 87.1169H221.981C235.863 87.1169 247.117 98.4218 247.117 112.367V142.867C247.117 156.812 235.863 168.117 221.981 168.117H189.514C184.701 168.117 180.085 166.196 176.682 162.777C169.14 155.201 155.38 141.379 147.547 133.511C144.307 130.256 144.307 124.978 147.547 121.723C155.38 113.855 169.14 100.033 176.682 92.4564Z",
      scale,
      center,
    );

    _createPathFromSVGData(
      upPath,
      "M92.4564 78.5521C89.0377 75.1487 87.1169 70.5327 87.1169 65.7196V33.2531C87.1169 19.3707 98.4218 8.11694 112.367 8.11694H142.867C156.812 8.11694 168.117 19.3707 168.117 33.2531V65.7196C168.117 70.5327 166.196 75.1487 162.777 78.5521C155.201 86.0944 141.379 99.8539 133.511 107.687C130.256 110.927 124.978 110.927 121.723 107.687C113.855 99.8539 100.033 86.0944 92.4564 78.5521Z",
      scale,
      center,
    );

    _createPathFromSVGData(
      downPath,
      "M162.777 176.682C166.196 180.085 168.117 184.701 168.117 189.514V221.981C168.117 235.863 156.812 247.117 142.867 247.117H112.367C98.4218 247.117 87.1169 235.863 87.1169 221.981V189.514C87.1169 184.701 89.0377 180.085 92.4564 176.682C100.033 169.14 113.855 155.38 121.723 147.547C124.978 144.307 130.256 144.307 133.511 147.547C141.379 155.38 155.201 169.14 162.777 176.682Z",
      scale,
      center,
    );

    _createPathFromSVGData(
      leftPath,
      "M78.5521 162.777C75.1487 166.196 70.5327 168.117 65.7196 168.117H33.2531C19.3707 168.117 8.11694 156.812 8.11694 142.867V112.367C8.11694 98.4218 19.3707 87.1169 33.2531 87.1169H65.7196C70.5327 87.1169 75.1487 89.0376 78.5521 92.4564C86.0944 100.033 99.854 113.855 107.687 121.723C110.927 124.978 110.927 130.256 107.687 133.511C99.854 141.379 86.0944 155.201 78.5521 162.777Z",
      scale,
      center,
    );
  }

  void _createPathFromSVGData(
    Path path,
    String svgPathData,
    double scale,
    Offset center,
  ) {
    // Better regex to separate commands from numbers
    final parts = svgPathData
        .replaceAllMapped(
          RegExp(r'([A-Za-z])'),
          (match) => ' ${match.group(0)} ',
        )
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();

    double currentX = 0, currentY = 0;
    double startX = 0, startY = 0;

    int i = 0;
    while (i < parts.length) {
      final part = parts[i];

      if (part.length == 1 && RegExp(r'[A-Za-z]').hasMatch(part)) {
        final command = part;
        i++;

        switch (command) {
          case 'M':
            if (i + 1 < parts.length) {
              currentX = double.parse(parts[i]);
              currentY = double.parse(parts[i + 1]);
              startX = currentX;
              startY = currentY;
              path.moveTo(
                center.dx + (currentX - 128) * scale,
                center.dy + (currentY - 128) * scale,
              );
              i += 2;
            }
            break;
          case 'C':
            if (i + 5 < parts.length) {
              final cp1x = double.parse(parts[i]);
              final cp1y = double.parse(parts[i + 1]);
              final cp2x = double.parse(parts[i + 2]);
              final cp2y = double.parse(parts[i + 3]);
              final endX = double.parse(parts[i + 4]);
              final endY = double.parse(parts[i + 5]);

              path.cubicTo(
                center.dx + (cp1x - 128) * scale,
                center.dy + (cp1y - 128) * scale,
                center.dx + (cp2x - 128) * scale,
                center.dy + (cp2y - 128) * scale,
                center.dx + (endX - 128) * scale,
                center.dy + (endY - 128) * scale,
              );
              currentX = endX;
              currentY = endY;
              i += 6;
            }
            break;
          case 'H':
            if (i < parts.length) {
              currentX = double.parse(parts[i]);
              path.lineTo(
                center.dx + (currentX - 128) * scale,
                center.dy + (currentY - 128) * scale,
              );
              i++;
            }
            break;
          case 'V':
            if (i < parts.length) {
              currentY = double.parse(parts[i]);
              path.lineTo(
                center.dx + (currentX - 128) * scale,
                center.dy + (currentY - 128) * scale,
              );
              i++;
            }
            break;
          case 'Z':
            path.close();
            currentX = startX;
            currentY = startY;
            break;
        }
      } else {
        i++; // Skip unrecognized tokens
      }
    }
  }
}

class _DPadPainter extends CustomPainter {
  final Set<int> activeSectors;
  final DPadPaths paths;
  final DpadController controller;

  _DPadPainter({
    required this.activeSectors,
    required this.paths,
    required this.controller,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawPath(canvas, paths.rightPath, 2);
    _drawPath(canvas, paths.upPath, 0);
    _drawPath(canvas, paths.downPath, 4);
    _drawPath(canvas, paths.leftPath, 6);
  }

  void _drawPath(Canvas canvas, Path path, int direction) {
    final isActive = activeSectors.contains(direction);
    final themeController = Get.find<GamepadThemeController>();
    final directionId = 'dpad_$direction';

    // 1. Draw Background Fill - D-pad controller tracks global active state
    final isDirectionActive =
        controller.isActive && activeSectors.contains(direction);
    final backgroundColor = themeController.getBackgroundColor(
      directionId,
      isDirectionActive,
    );
    final fillPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);

    // 2. Draw Inner Shadows (inward from edges)
    canvas.save();
    canvas.clipPath(path);

    final bounds = path.getBounds();
    final center = bounds.center;
    final innerShadows = themeController.getInnerShadows(directionId, isActive);

    for (final shadow in innerShadows) {
      final outerBound = bounds.inflate(
        shadow.spreadRadius + shadow.blurRadius + shadow.offset.dx.abs(),
      );
      final innerPath = _createInsetPath(
        path,
        center,
        shadow.spreadRadius,
        shadow.offset,
      );
      final shadowPath = Path.combine(
        PathOperation.difference,
        Path()..addRect(outerBound),
        innerPath,
      );

      final shadowPaint = Paint()
        ..color = shadow.color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurRadius);
      canvas.drawPath(shadowPath, shadowPaint);
    }

    canvas.restore();
  }

  Path _createInsetPath(
    Path originalPath,
    Offset center,
    double spreadRadius,
    Offset offset,
  ) {
    // Scale down the path according to the spread diameter (radius * 2)
    final bounds = originalPath.getBounds();
    final scaleX = 1 - ((spreadRadius * 2) / bounds.width);
    final scaleY = 1 - ((spreadRadius * 2) / bounds.height);

    // Create transformation matrices
    final translateToOrigin = Matrix4.identity()
      ..translate(-center.dx, -center.dy);

    final scalingMatrix = Matrix4.identity()..scale(scaleX, scaleY);

    final translateBack = Matrix4.identity()
      ..translate(center.dx + offset.dx, center.dy + offset.dy);

    // Combine the matrices: translate back * scale * translate to origin
    final combinedMatrix = translateBack
        .multiplied(scalingMatrix)
        .multiplied(translateToOrigin);

    return originalPath.transform(combinedMatrix.storage);
  }

  @override
  bool shouldRepaint(covariant _DPadPainter oldDelegate) {
    return oldDelegate.activeSectors.length != activeSectors.length ||
        !oldDelegate.activeSectors.containsAll(activeSectors);
  }
}
