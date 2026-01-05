import 'package:flutter/material.dart';
import 'dart:math';

/// Helper class to render inner shadows on any given path.
class InnerShadowRenderer {
  static void paint(
    Canvas canvas, {
    required Path shapePath,
    required List<BoxShadow> shadows,
    Path? holePath, // If provided, used as the "deflated" path for spread calculation
  }) {
    if (shadows.isEmpty) return;

    canvas.save();
    canvas.clipPath(shapePath);

    for (final shadow in shadows) {
      if (shadow.color.a == 0) continue;

      final Paint shadowPaint = shadow.toPaint();
      final Rect bounds = shapePath.getBounds();
      
      // Helper to inflate rect sufficiently to contain the blur/spread
      final double margin = shadow.blurRadius + shadow.spreadRadius.abs() + max(shadow.offset.dx.abs(), shadow.offset.dy.abs()) + 50;
      
      final Rect outerRect = bounds.inflate(margin);
      
      // 1. Create the shadow geometry (The "Caster")
      final Path casterPath = Path()..addRect(outerRect);
      
      // 2. Determine the hole
      Path effectiveHolePath;
      if (holePath != null) {
        effectiveHolePath = holePath;
      } else if (shadow.spreadRadius == 0) {
        effectiveHolePath = shapePath;
      } else {
         // Fallback: we can't easily deflate arbitrary paths without library support.
         // In this case, we ignore spreadRadius for the hole geometry if custom holePath isn't provided.
         // Or we could try to use the shapePath itself, which means spread won't visibly "choke" the shadow,
         // but blur and offset will still work.
         effectiveHolePath = shapePath;
      }
      
      // Combine to make the "solid with hole"
      casterPath.addPath(effectiveHolePath, Offset.zero);
      casterPath.fillType = PathFillType.evenOdd;

      // 3. Draw the shadow
      canvas.save();
      canvas.translate(shadow.offset.dx, shadow.offset.dy);
      canvas.drawPath(casterPath, shadowPaint);
      canvas.restore();
    }

    canvas.restore();
  }
}

class InnerShadowPainter extends CustomPainter {
  final List<BoxShadow> shadows;
  final BoxShape shape;
  final BorderRadiusGeometry? borderRadius;
  final Clip clipBehavior;
  final Path? path; // Support for explicit path (though spread might be limited)

  InnerShadowPainter({
    required this.shadows,
    this.shape = BoxShape.rectangle,
    this.borderRadius,
    this.clipBehavior = Clip.antiAlias,
    this.path,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Determine the clip path
    final Path clipPath = path ?? _getShapePath(size);

    // 2. Paint using renderer
    // Note: For BoxShapes, we can calculate the "holePath" dynamically per shadow spread
    // in the renderer if we passed the geometry info, OR we calculate it here.
    // The Renderer is generic, so it expects paths.
    // To support spread correctly for BoxShapes, we should manually handle loop here
    // OR make Renderer smarter. 
    // Let's stick to the manual loop here to leverage `_deflatePath` which we have.
    
    if (shadows.isEmpty) return;
    
    canvas.save();
    canvas.clipPath(clipPath);

    for (final shadow in shadows) {
        // Calculate hole path for this specific shadow's spread
        Path holePath;
        if (path != null) {
            // For arbitrary paths, we don't support auto-deflation yet.
            holePath = path!; 
        } else {
            holePath = _deflatePath(clipPath, shadow.spreadRadius, clipPath.getBounds());
        }
        
        // Use a simplified one-shot render for this single shadow
        InnerShadowRenderer.paint(
            canvas, 
            shapePath: clipPath, 
            shadows: [shadow], 
            holePath: holePath
        );
    }
    
    canvas.restore();
  }

  Path _getShapePath(Size size) {
    if (shape == BoxShape.circle) {
      return Path()
        ..addOval(Rect.fromLTWH(0, 0, size.width, size.height));
    } else {
      // BoxShape.rectangle
      if (borderRadius != null) {
        return Path()
          ..addRRect(
            borderRadius!.resolve(TextDirection.ltr).toRRect(
              Rect.fromLTWH(0, 0, size.width, size.height),
            ),
          );
      } else {
        return Path()
          ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      }
    }
  }

  Path _deflatePath(Path path, double delta, Rect bounds) {
    // Simple deflation for basic shapes
    if (shape == BoxShape.circle) {
      final double radius = bounds.width / 2;
      final double newRadius = max(0.0, radius - delta);
      return Path()..addOval(Rect.fromCircle(center: bounds.center, radius: newRadius));
    } else {
      // Rectangle or RRect
      if (borderRadius != null) {
        final RRect rrect = borderRadius!.resolve(TextDirection.ltr).toRRect(bounds);
        final RRect newRRect = rrect.deflate(delta);
        return Path()..addRRect(newRRect);
      } else {
        return Path()..addRect(bounds.deflate(delta));
      }
    }
  }

  @override
  bool shouldRepaint(InnerShadowPainter oldDelegate) {
    return oldDelegate.shadows != shadows ||
           oldDelegate.shape != shape ||
           oldDelegate.borderRadius != borderRadius ||
           oldDelegate.path != path;
  }
}
