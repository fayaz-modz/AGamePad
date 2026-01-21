import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Shader-based inner shadow implementation for high performance.
/// This class manages the fragment shader lifecycle and caching.
class InnerShadowShader {
  static ui.FragmentProgram? _program;
  static bool _isLoading = false;
  static final List<VoidCallback> _pendingCallbacks = [];

  /// Returns true if the shader is ready to use
  static bool get isReady => _program != null;

  /// Load the shader program. Call this early (e.g., in main())
  static Future<void> load() async {
    if (_program != null || _isLoading) return;
    _isLoading = true;

    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/inner_shadow.frag');
      // Notify all pending callbacks
      for (final callback in _pendingCallbacks) {
        callback();
      }
      _pendingCallbacks.clear();
    } catch (e) {
      debugPrint('Failed to load inner shadow shader: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// Register a callback to be called when shader is ready
  static void onReady(VoidCallback callback) {
    if (_program != null) {
      callback();
    } else {
      _pendingCallbacks.add(callback);
      // Ensure loading is in progress
      load();
    }
  }

  /// Create a fragment shader instance
  static ui.FragmentShader? createShader() {
    return _program?.fragmentShader();
  }
}

/// Use this class to define an inset box shadow that can be used inside the [InsetShadowShapeDecoration] shadows.
final class InsetBoxShadow extends BoxShadow {
  const InsetBoxShadow({
    super.color,
    super.offset,
    super.blurRadius,
    super.spreadRadius = 0.0,
    super.blurStyle = BlurStyle.normal,
  });
}

/// A shape decoration that supports inset shadows by adding [InsetBoxShadow] instances to the [shadows] prop.
/// This implementation uses GPU shaders for high performance rendering.
class InsetShadowShapeDecoration extends ShapeDecoration {
  const InsetShadowShapeDecoration({
    required super.shape,
    super.color,
    super.image,
    super.gradient,
    super.shadows,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _ShaderShapeDecorationPainter(this, onChanged ?? () {});
  }
}

/// An object that paints a [InsetShadowShapeDecoration] into a canvas using GPU shaders.
class _ShaderShapeDecorationPainter extends BoxPainter {
  _ShaderShapeDecorationPainter(this._decoration, VoidCallback onChanged)
      : super(onChanged) {
    // Ensure shader is loading
    if (!InnerShadowShader.isReady) {
      InnerShadowShader.onReady(onChanged);
    }
  }

  final InsetShadowShapeDecoration _decoration;

  Rect? _lastRect;
  TextDirection? _lastTextDirection;
  late Path _outerPath;
  Path? _innerPath;
  Paint? _interiorPaint;
  List<BoxShadow> _shadowsWithoutInset = [];
  List<BoxShadow> _insetShadows = [];
  late List<Rect> _shadowBounds;
  late List<Path> _shadowPaths;
  late List<Paint> _shadowPaints;

  // Shader-related caching
  ui.FragmentShader? _cachedShader;
  int _lastShadowsHash = 0;

  @override
  VoidCallback get onChanged => super.onChanged!;

  void _precache(Rect rect, TextDirection? textDirection) {
    if (rect == _lastRect && textDirection == _lastTextDirection) {
      return;
    }

    if (_interiorPaint == null &&
        (_decoration.color != null || _decoration.gradient != null)) {
      _interiorPaint = Paint();
      if (_decoration.color != null) {
        _interiorPaint!.color = _decoration.color!;
      }
    }

    if (_decoration.gradient != null) {
      _interiorPaint!.shader = _decoration.gradient!.createShader(
        rect,
        textDirection: textDirection,
      );
    }

    if (_decoration.shadows != null) {
      final currentShadowsHash = _decoration.shadows!.hashCode;
      if (currentShadowsHash != _lastShadowsHash) {
        _lastShadowsHash = currentShadowsHash;

        _shadowsWithoutInset = [];
        _insetShadows = [];
        for (final shadow in _decoration.shadows!) {
          if (shadow is InsetBoxShadow) {
            _insetShadows.add(shadow);
          } else {
            _shadowsWithoutInset.add(shadow);
          }
        }
      }

      if (_shadowsWithoutInset.isNotEmpty) {
        _shadowPaints = <Paint>[
          ..._shadowsWithoutInset.map((BoxShadow shadow) => shadow.toPaint()),
        ];
      }
      if (_decoration.shape.preferPaintInterior) {
        _shadowBounds = <Rect>[
          ..._shadowsWithoutInset.map((BoxShadow shadow) {
            return rect.shift(shadow.offset).inflate(shadow.spreadRadius);
          }),
        ];
      } else {
        _shadowPaths = <Path>[
          ..._shadowsWithoutInset.map((BoxShadow shadow) {
            return _decoration.shape.getOuterPath(
              rect.shift(shadow.offset).inflate(shadow.spreadRadius),
              textDirection: textDirection,
            );
          }),
        ];
      }
    }

    if (!_decoration.shape.preferPaintInterior &&
        (_interiorPaint != null || _shadowsWithoutInset.isNotEmpty)) {
      _outerPath = _decoration.shape.getOuterPath(
        rect,
        textDirection: textDirection,
      );
    }

    if (_decoration.image != null || _insetShadows.isNotEmpty) {
      _innerPath = _decoration.shape.getInnerPath(
        rect,
        textDirection: textDirection,
      );
    }

    _lastRect = rect;
    _lastTextDirection = textDirection;
  }

  void _paintShadows(Canvas canvas, Rect rect, TextDirection? textDirection) {
    if (_shadowsWithoutInset.isEmpty) {
      return;
    }

    bool debugHandleDisabledShadowStart(
      Canvas canvas,
      BoxShadow boxShadow,
      Path path,
    ) {
      if (debugDisableShadows && boxShadow.blurStyle == BlurStyle.outer) {
        canvas.save();
        final Path clipPath = Path();
        clipPath.fillType = PathFillType.evenOdd;
        clipPath.addRect(Rect.largest);
        clipPath.addPath(path, Offset.zero);
        canvas.clipPath(clipPath);
      }
      return true;
    }

    bool debugHandleDisabledShadowEnd(Canvas canvas, BoxShadow boxShadow) {
      if (debugDisableShadows && boxShadow.blurStyle == BlurStyle.outer) {
        canvas.restore();
      }
      return true;
    }

    if (_decoration.shape.preferPaintInterior) {
      for (int index = 0; index < _shadowsWithoutInset.length; index += 1) {
        assert(
          debugHandleDisabledShadowStart(
            canvas,
            _shadowsWithoutInset[index],
            _decoration.shape.getOuterPath(
              _shadowBounds[index],
              textDirection: textDirection,
            ),
          ),
        );
        _decoration.shape.paintInterior(
          canvas,
          _shadowBounds[index],
          _shadowPaints[index],
          textDirection: textDirection,
        );
        assert(
          debugHandleDisabledShadowEnd(canvas, _shadowsWithoutInset[index]),
        );
      }
    } else {
      for (int index = 0; index < _shadowsWithoutInset.length; index += 1) {
        assert(
          debugHandleDisabledShadowStart(
            canvas,
            _shadowsWithoutInset[index],
            _shadowPaths[index],
          ),
        );
        canvas.drawPath(_shadowPaths[index], _shadowPaints[index]);
        assert(
          debugHandleDisabledShadowEnd(canvas, _shadowsWithoutInset[index]),
        );
      }
    }
  }

  void _paintInterior(Canvas canvas, Rect rect, TextDirection? textDirection) {
    if (_interiorPaint != null) {
      if (_decoration.shape.preferPaintInterior) {
        final Rect adjustedRect = _adjustedRectOnOutlinedBorder(rect);
        _decoration.shape.paintInterior(
          canvas,
          adjustedRect,
          _interiorPaint!,
          textDirection: textDirection,
        );
      } else {
        canvas.drawPath(_outerPath, _interiorPaint!);
      }
    }
  }

  Rect _adjustedRectOnOutlinedBorder(Rect rect) {
    if (_decoration.shape is OutlinedBorder && _decoration.color != null) {
      final BorderSide side = (_decoration.shape as OutlinedBorder).side;
      if (side.color.a == 1 && side.style == BorderStyle.solid) {
        return rect.deflate(side.strokeInset / 2);
      }
    }
    return rect;
  }

  DecorationImagePainter? _imagePainter;
  void _paintImage(Canvas canvas, ImageConfiguration configuration) {
    if (_decoration.image == null) {
      return;
    }
    _imagePainter ??= _decoration.image!.createPainter(onChanged);
    _imagePainter!.paint(canvas, _lastRect!, _innerPath, configuration);
  }

  /// Paint inset shadows using GPU shader for maximum performance
  void _paintInsetShadowsWithShader(
    Canvas canvas,
    Rect rect,
    TextDirection? textDirection,
  ) {
    if (_insetShadows.isEmpty || _innerPath == null) {
      return;
    }

    // Only use shader if it's ready
    if (!InnerShadowShader.isReady) {
      // Fallback to CPU-based rendering while shader loads
      _paintInsetShadowsFallback(canvas, rect, textDirection);
      return;
    }

    // Create or update shader
    _cachedShader ??= InnerShadowShader.createShader();
    if (_cachedShader == null) {
      _paintInsetShadowsFallback(canvas, rect, textDirection);
      return;
    }

    final shader = _cachedShader!;

    // Determine if shape is a circle and extract per-corner radii
    final bool isCircle = _decoration.shape is CircleBorder;
    
    // Per-corner radii: (topLeft, topRight, bottomRight, bottomLeft)
    double tlRadius = 0.0;
    double trRadius = 0.0;
    double brRadius = 0.0;
    double blRadius = 0.0;
    
    if (isCircle) {
      // For circles, use half the minimum dimension for all corners
      final radius = min(rect.width, rect.height) / 2.0;
      tlRadius = trRadius = brRadius = blRadius = radius;
    } else if (_decoration.shape is RoundedRectangleBorder) {
      final rrb = _decoration.shape as RoundedRectangleBorder;
      final borderRadius = rrb.borderRadius.resolve(textDirection);
      // Apply 0.5x scale to match Flutter's rendering of the same radius values
      tlRadius = borderRadius.topLeft.x * 0.5;
      trRadius = borderRadius.topRight.x * 0.5;
      brRadius = borderRadius.bottomRight.x * 0.5;
      blRadius = borderRadius.bottomLeft.x * 0.5;
    }

    // Set uniform values (index matches shader declaration order)
    int uniformIndex = 0;

    // uSize (vec2)
    shader.setFloat(uniformIndex++, rect.width);
    shader.setFloat(uniformIndex++, rect.height);

    // uIsCircle (float)
    shader.setFloat(uniformIndex++, isCircle ? 1.0 : 0.0);

    // uCornerRadii (vec4): topLeft, topRight, bottomRight, bottomLeft
    shader.setFloat(uniformIndex++, tlRadius);
    shader.setFloat(uniformIndex++, trRadius);
    shader.setFloat(uniformIndex++, brRadius);
    shader.setFloat(uniformIndex++, blRadius);

    // Set up to 4 shadows
    for (int i = 0; i < 4; i++) {
      if (i < _insetShadows.length) {
        final shadow = _insetShadows[i];
        // Color (vec4) - premultiplied alpha
        final color = shadow.color;
        shader.setFloat(uniformIndex++, color.r);
        shader.setFloat(uniformIndex++, color.g);
        shader.setFloat(uniformIndex++, color.b);
        shader.setFloat(uniformIndex++, color.a);
        // Offset (vec2)
        shader.setFloat(uniformIndex++, shadow.offset.dx);
        shader.setFloat(uniformIndex++, shadow.offset.dy);
        // BlurRadius (float)
        shader.setFloat(uniformIndex++, shadow.blurRadius);
        // SpreadRadius (float)
        shader.setFloat(uniformIndex++, shadow.spreadRadius);
      } else {
        // Unused shadow slot - set alpha to 0
        shader.setFloat(uniformIndex++, 0.0); // r
        shader.setFloat(uniformIndex++, 0.0); // g
        shader.setFloat(uniformIndex++, 0.0); // b
        shader.setFloat(uniformIndex++, 0.0); // a (disabled)
        shader.setFloat(uniformIndex++, 0.0); // offset.x
        shader.setFloat(uniformIndex++, 0.0); // offset.y
        shader.setFloat(uniformIndex++, 0.0); // blur
        shader.setFloat(uniformIndex++, 0.0); // spread
      }
    }

    // Draw with shader
    canvas.save();
    canvas.clipPath(_innerPath!);
    canvas.translate(rect.left, rect.top);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & rect.size, paint);

    canvas.restore();
  }

  /// Fallback CPU-based rendering when shader is not available
  void _paintInsetShadowsFallback(
    Canvas canvas,
    Rect rect,
    TextDirection? textDirection,
  ) {
    if (_innerPath == null) return;

    canvas.save();
    canvas.clipPath(_innerPath!);

    for (final shadow in _insetShadows) {
      final paint = shadow.toPaint();
      final center = rect.center;

      final outerBound = rect.inflate(
        shadow.spreadRadius +
            shadow.blurRadius +
            max(shadow.offset.dx.abs(), shadow.offset.dy.abs()),
      );

      final translateToOrigin = Matrix4.identity()
        ..translateByDouble(-center.dx, -center.dy, 0, 1);

      final scaleX = 1 - ((shadow.spreadRadius * 2) / rect.width);
      final scaleY = 1 - ((shadow.spreadRadius * 2) / rect.height);
      final scalingMatrix = Matrix4.identity()..scaleByDouble(scaleX, scaleY, 1, 1);

      final translateX = center.dx + shadow.offset.dx;
      final translateY = center.dy + shadow.offset.dy;
      final translateBack = Matrix4.identity()..translateByDouble(translateX, translateY, 0, 1);

      final combinedMatrix = translateBack.multiplied(scalingMatrix).multiplied(translateToOrigin);

      final innerPathOfTheInsetShadow = _innerPath!.transform(combinedMatrix.storage);

      final path = Path.combine(
        PathOperation.difference,
        Path()..addRect(outerBound),
        innerPathOfTheInsetShadow,
      );
      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  @override
  void dispose() {
    _imagePainter?.dispose();
    super.dispose();
  }

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    assert(configuration.size != null);
    final Rect rect = offset & configuration.size!;
    final TextDirection? textDirection = configuration.textDirection;

    _precache(rect, textDirection);
    _paintShadows(canvas, rect, textDirection);
    _paintInterior(canvas, rect, textDirection);
    _paintImage(canvas, configuration);
    _paintInsetShadowsWithShader(canvas, rect, textDirection);
    _decoration.shape.paint(canvas, rect, textDirection: textDirection);
  }
}
