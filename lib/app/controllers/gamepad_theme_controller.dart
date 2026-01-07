import 'package:flutter/material.dart';
import 'package:get/get.dart';

class InnerShadowConfig {
  final Color color;
  final double blurRadius;
  final double spreadRadius;
  final Offset offset;

  const InnerShadowConfig({
    required this.color,
    required this.blurRadius,
    required this.spreadRadius,
    required this.offset,
  });

  InnerShadowConfig copyWith({
    Color? color,
    double? blurRadius,
    double? spreadRadius,
    Offset? offset,
  }) {
    return InnerShadowConfig(
      color: color ?? this.color,
      blurRadius: blurRadius ?? this.blurRadius,
      spreadRadius: spreadRadius ?? this.spreadRadius,
      offset: offset ?? this.offset,
    );
  }
}

class BorderConfig {
  final Color color;
  final double width;
  final BorderRadius borderRadius;

  const BorderConfig({
    required this.color,
    required this.width,
    required this.borderRadius,
  });

  BorderConfig copyWith({
    Color? color,
    double? width,
    BorderRadius? borderRadius,
  }) {
    return BorderConfig(
      color: color ?? this.color,
      width: width ?? this.width,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }
}

class BackgroundConfig {
  final Color color;
  final Color activeColor;

  const BackgroundConfig({required this.color, required this.activeColor});

  BackgroundConfig copyWith({Color? color, Color? activeColor}) {
    return BackgroundConfig(
      color: color ?? this.color,
      activeColor: activeColor ?? this.activeColor,
    );
  }
}

class GamepadTheme {
  final InnerShadowConfig innerShadow;
  final BorderConfig border;
  final BackgroundConfig background;

  const GamepadTheme({
    required this.innerShadow,
    required this.border,
    required this.background,
  });

  GamepadTheme withTheme({
    InnerShadowConfig? innerShadow,
    BorderConfig? border,
    BackgroundConfig? background,
  }) {
    return GamepadTheme(
      innerShadow: innerShadow ?? this.innerShadow,
      border: border ?? this.border,
      background: background ?? this.background,
    );
  }
}

class GamepadThemeController extends GetxController {
  // Base theme for all elements
  late final GamepadTheme baseTheme;

  // Specific themes per button type (optional overrides)
  final Map<String, GamepadTheme> _buttonThemes = {};

  GamepadThemeController({
    InnerShadowConfig? innerShadow,
    BorderConfig? border,
    BackgroundConfig? background,
  }) {
    baseTheme = GamepadTheme(
      innerShadow: innerShadow ?? _defaultInnerShadow,
      border: border ?? _defaultBorder,
      background: background ?? _defaultBackground,
    );
  }

  // Default configurations
  static const InnerShadowConfig _defaultInnerShadow = InnerShadowConfig(
    color: Color.fromRGBO(255, 255, 255, 0.2),
    blurRadius: 15,
    spreadRadius: 6,
    offset: Offset(3, 3),
  );

  static const InnerShadowConfig _defaultInnerShadowSecondary =
      InnerShadowConfig(
        color: Color.fromRGBO(255, 255, 255, 0.1),
        blurRadius: 8,
        spreadRadius: 2,
        offset: Offset(1, 1),
      );

  static const BorderConfig _defaultBorder = BorderConfig(
    color: Colors.transparent,
    width: 0,
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );

  static const BackgroundConfig _defaultBackground = BackgroundConfig(
    color: Color.fromRGBO(255, 255, 255, 0.15),
    activeColor: Color.fromRGBO(255, 255, 255, 0.25),
  );

  // Get theme for specific button ID
  GamepadTheme getTheme(String? buttonId) {
    if (buttonId != null && _buttonThemes.containsKey(buttonId)) {
      return _buttonThemes[buttonId]!;
    }
    return baseTheme;
  }

  // Get inner shadows including secondary shadow
  List<InnerShadowConfig> getInnerShadows(String? buttonId, bool isActive) {
    final theme = getTheme(buttonId);
    final primaryShadow = theme.innerShadow.copyWith(
      color: theme.innerShadow.color.withValues(
        alpha: isActive
            ? theme.innerShadow.color.a * 1.5
            : theme.innerShadow.color.a,
      ),
    );

    final secondaryShadow = _defaultInnerShadowSecondary.copyWith(
      color: _defaultInnerShadowSecondary.color.withValues(
        alpha: isActive
            ? _defaultInnerShadowSecondary.color.a * 1.5
            : _defaultInnerShadowSecondary.color.a,
      ),
    );

    return [primaryShadow, secondaryShadow];
  }

  // Get background color based on active state
  Color getBackgroundColor(String? buttonId, bool isActive) {
    final theme = getTheme(buttonId);
    return isActive ? theme.background.activeColor : theme.background.color;
  }

  // Get border config
  BorderConfig getBorderConfig(String? buttonId) {
    return getTheme(buttonId).border;
  }

  // Set custom theme for specific button
  void setButtonTheme(String buttonId, GamepadTheme theme) {
    _buttonThemes[buttonId] = theme;
    update();
  }

  // Set custom theme for specific button using withTheme
  void setButtonThemeWithOverrides(
    String buttonId, {
    InnerShadowConfig? innerShadow,
    BorderConfig? border,
    BackgroundConfig? background,
  }) {
    final buttonTheme = baseTheme.withTheme(
      innerShadow: innerShadow,
      border: border,
      background: background,
    );
    _buttonThemes[buttonId] = buttonTheme;
    update();
  }

  // Update base theme
  void updateBaseTheme({
    InnerShadowConfig? innerShadow,
    BorderConfig? border,
    BackgroundConfig? background,
  }) {
    baseTheme = GamepadTheme(
      innerShadow: innerShadow ?? baseTheme.innerShadow,
      border: border ?? baseTheme.border,
      background: background ?? baseTheme.background,
    );
    update();
  }

  // Clear custom theme for specific button
  void clearButtonTheme(String buttonId) {
    _buttonThemes.remove(buttonId);
    update();
  }

  // Clear all custom button themes
  void clearAllButtonThemes() {
    _buttonThemes.clear();
    update();
  }
}
