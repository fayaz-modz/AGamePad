import 'dart:math';
import 'package:flutter/material.dart';

class CircularDPad extends StatefulWidget {
  final ValueChanged<int> onDown;
  final VoidCallback onUp;
  final double size;

  const CircularDPad({
    super.key,
    required this.onDown,
    required this.onUp,
    this.size = 150.0,
  });

  @override
  State<CircularDPad> createState() => _CircularDPadState();
}

class _CircularDPadState extends State<CircularDPad> {
  int _currentValue = 0;

  // Map current value to active visual sectors for the painter
  Set<int> get _activeVisualSectors {
    final s = <int>{};
    if (_currentValue == 8) return s; // 8 is Center/Null
    
    // 0=Up, 1=UpRight, 2=Right, 3=DownRight, 4=Down, 5=DownLeft, 6=Left, 7=UpLeft
    if ([0, 1, 7].contains(_currentValue)) s.add(0); // Up
    if ([2, 1, 3].contains(_currentValue)) s.add(2); // Right
    if ([4, 3, 5].contains(_currentValue)) s.add(4); // Down
    if ([6, 5, 7].contains(_currentValue)) s.add(6); // Left
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: Listener(
        onPointerDown: (event) => _handleInput(event.localPosition),
        onPointerMove: (event) => _handleInput(event.localPosition),
        onPointerUp: (_) => _handleUp(),
        onPointerCancel: (_) => _handleUp(),
        child: CustomPaint(
          painter: _DPadPainter(activeSectors: _activeVisualSectors),
        ),
      ),
    );
  }

  void _handleUp() {
    if (_currentValue != 8) {
      setState(() {
        _currentValue = 8;
      });
      widget.onUp();
    }
  }

  void _handleInput(Offset localPosition) {
    // Calculate center and use consistent radius for normalization
    final centerX = widget.size / 2;
    final centerY = widget.size / 2;
    final radius = widget.size / 2;
    
    // Calculate normalized x, y coordinates from center (-1 to +1 range)
    final dx = localPosition.dx - centerX;
    final dy = localPosition.dy - centerY;
    final x = dx / radius;
    final y = dy / radius;
    
    // Deadzone check (circular, 10% of radius)
    final distance = sqrt(x * x + y * y);
    if (distance < 0.10) {
      _handleUp();
      return;
    }

    // Simple threshold-based direction detection (15% threshold)
    const threshold = 0.15;
    final isUp = y < -threshold;
    final isDown = y > threshold;
    final isLeft = x < -threshold;
    final isRight = x > threshold;

    // Map to D-pad value (0-8 hat switch standard)
    // 0=Up, 1=UpRight, 2=Right, 3=DownRight, 4=Down, 5=DownLeft, 6=Left, 7=UpLeft, 8=Center
    int dpadValue = 8;
    
    if (isUp && isRight) {
      dpadValue = 1;
    } else if (isDown && isRight) {
      dpadValue = 3;
    } else if (isDown && isLeft) {
      dpadValue = 5;
    } else if (isUp && isLeft) {
      dpadValue = 7;
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
    if (_currentValue != dpadValue) {
      setState(() {
        _currentValue = dpadValue;
      });
      
      // Send onDown event for any new direction (including fast taps)
      if (dpadValue != 8) {
        widget.onDown(dpadValue);
      }
    }
  }
}

class _DPadPainter extends CustomPainter {
  final Set<int> activeSectors;

  _DPadPainter({required this.activeSectors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    final bgPaint = Paint()
      ..color = Colors.grey[900]!
      ..style = PaintingStyle.fill;
      
    final borderPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw main circle
    canvas.drawCircle(center, radius, bgPaint);
    
    // Draw 4 sectors text/lines
    final linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2;

    // Highlight active sectors
    final highlightPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    // We only visually represent 4 sectors: Up(1), Right(3), Down(5), Left(7)
    // Up Sector: 225 deg to 315 deg? No, Up is 270. Sector spans 225 to 315 (90 deg total)
    // Actually user asks for "only 4 sectors". 
    // Let's define visual sectors as 90 degrees each centered on the direction.
    // UP: 225 to 315. RIGHT: 315 to 45 (wrap). DOWN: 45 to 135. LEFT: 135 to 225.
    
    void drawSector(int dir, double startAngle) {
       if (activeSectors.contains(dir)) {
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius),
            startAngle * pi / 180,
            90 * pi / 180,
            true,
            highlightPaint
          );
       }
    }

    drawSector(2, 315); // Right
    drawSector(4, 45);  // Down
    drawSector(6, 135); // Left
    drawSector(0, 225); // Up

    // Draw dividing lines for visual separation (X shape)
    canvas.drawLine(
      center + Offset.fromDirection((45 * pi / 180), radius * 0.3),
      center + Offset.fromDirection((45 * pi / 180), radius), 
      linePaint
    );
     canvas.drawLine(
      center + Offset.fromDirection((135 * pi / 180), radius * 0.3),
      center + Offset.fromDirection((135 * pi / 180), radius), 
      linePaint
    );
     canvas.drawLine(
      center + Offset.fromDirection((225 * pi / 180), radius * 0.3),
      center + Offset.fromDirection((225 * pi / 180), radius), 
      linePaint
    );
     canvas.drawLine(
      center + Offset.fromDirection((315 * pi / 180), radius * 0.3),
      center + Offset.fromDirection((315 * pi / 180), radius), 
      linePaint
    );

    canvas.drawCircle(center, radius, borderPaint);
    
    // Draw arrows
    final arrowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    // Arrows should look like triangles
    _drawArrow(canvas, center, radius * 0.6, 0, arrowPaint);   // Right
    _drawArrow(canvas, center, radius * 0.6, 90, arrowPaint);  // Down
    _drawArrow(canvas, center, radius * 0.6, 180, arrowPaint); // Left
    _drawArrow(canvas, center, radius * 0.6, 270, arrowPaint); // Up
  }

  void _drawArrow(Canvas canvas, Offset center, double distance, double angleDeg, Paint paint) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angleDeg * pi / 180);
    
    final path = Path();
    path.moveTo(distance + 15, 0);
    path.lineTo(distance - 5, -12);
    path.lineTo(distance - 5, 12);
    path.close();
    
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DPadPainter oldDelegate) {
    return oldDelegate.activeSectors.length != activeSectors.length || 
           !oldDelegate.activeSectors.containsAll(activeSectors);
  }
}
