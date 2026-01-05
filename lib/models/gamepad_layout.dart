import 'gamepad_descriptor.dart';

class GamepadLayout {
  final String id;
  final String name;
  final List<GamepadControl> controls;

  GamepadLayout({required this.id, required this.name, required this.controls});

  static GamepadLayout xbox() {
    return GamepadLayout(
      id: 'xbox_default',
      name: 'Xbox Style',
      controls: [
        // Left side - use left edge positioning
        GamepadControl(
          id: 'l_joystick',
          type: ControlType.joystick,
          left: 260, // Pixels from left
          bottom: 100, // Pixels from bottom
          width: 140,
          height: 140,
          joystickMapping: Joystick.left,
        ),
        GamepadControl(
          id: 'dpad',
          type: ControlType.dpad,
          left: 130, // Pixels from left
          bottom: 200, // Pixels from top
          width: 150,
          height: 150,
        ),

        // Right side - use right edge positioning
        GamepadControl(
          id: 'r_joystick',
          type: ControlType.joystick,
          right: 260, // Pixels from left
          bottom: 100, // Pixels from bottom
          width: 140,
          height: 140,
          joystickMapping: Joystick.right,
        ),
        GamepadControl(
          id: 'abxy',
          type: ControlType.buttonCluster,
          right: 130, // Pixels from left
          bottom: 200, // Pixels from top
          width: 160,
          height: 160,
          // Xbox Standard: A-Bottom, B-Right, X-Left, Y-Top
          clusterBottom: GamepadButton.button1,
          clusterRight: GamepadButton.button2,
          clusterLeft: GamepadButton.button3,
          clusterTop: GamepadButton.button4,
        ),

        // Shoulders
        GamepadControl(
          id: 'l1',
          type: ControlType.shoulderButton,
          left: 210, // Pixels from left
          bottom: 330, // Pixels from top
          width: 70,
          height: 70,
          buttonMapping: GamepadButton.l1,
        ),
        GamepadControl(
          id: 'l2',
          type: ControlType.shoulderButton,
          left: 270, // Pixels from left
          bottom: 270, // Pixels from top
          width: 70,
          height: 70,
          buttonMapping: GamepadButton.l2,
        ),

        GamepadControl(
          id: 'r1',
          type: ControlType.shoulderButton,
          right: 210, // Pixels from left
          bottom: 330, // Pixels from top
          width: 70,
          height: 70,
          buttonMapping: GamepadButton.r1,
        ),
        GamepadControl(
          id: 'r2',
          type: ControlType.shoulderButton,
          right: 270, // Pixels from left
          bottom: 270, // Pixels from top
          width: 70,
          height: 70,
          buttonMapping: GamepadButton.r2,
        ),

        // Center buttons - can use left or calculate from center
        GamepadControl(
          id: 'select',
          type: ControlType.button,
          centerHorizontal: true,
          offsetX: -60,
          bottom: 180, // Pixels from top
          width: 64,
          height: 40,
          buttonMapping: GamepadButton.select,
        ),
        GamepadControl(
          id: 'start',
          type: ControlType.button,
          centerHorizontal: true,
          offsetX: 60,
          bottom: 180, // Pixels from top
          width: 64,
          height: 40,
          buttonMapping: GamepadButton.start,
        ),
        GamepadControl(
          id: 'mode',
          type: ControlType.button,
          centerHorizontal: true, // Center horizontally
          bottom: 230, // Pixels from bottom
          width: 64,
          height: 40,
          buttonMapping: GamepadButton.home,
        ),
      ],
    );
  }

  static GamepadLayout android() {
    return GamepadLayout(
      id: 'android_default',
      name: 'Android',
      controls: [
        // Left side - use left edge positioning
        GamepadControl(
          id: 'l_joystick',
          type: ControlType.joystick,
          left: 260, // Pixels from left
          bottom: 100, // Pixels from bottom
          width: 140,
          height: 140,
          joystickMapping: Joystick.left,
        ),
        GamepadControl(
          id: 'dpad',
          type: ControlType.dpad,
          left: 130, // Pixels from left
          bottom: 200, // Pixels from top
          width: 150,
          height: 150,
        ),

        // Right side - use right edge positioning
        GamepadControl(
          id: 'r_joystick',
          type: ControlType.joystick,
          right: 260, // Pixels from left
          bottom: 100, // Pixels from bottom
          width: 140,
          height: 140,
          joystickMapping: Joystick.right,
        ),
        GamepadControl(
          id: 'abxycz',
          type: ControlType.buttonCluster,
          right: 130, // Pixels from left
          bottom: 200, // Pixels from top
          width: 240,
          height: 160,
          // Xbox Standard: A-Bottom, B-Right, X-Left, Y-Top
          clusterBottom: GamepadButton.button1,
          clusterRight: GamepadButton.button2,
          clusterLeft: GamepadButton.button3,
          clusterTop: GamepadButton.button4,
          clusterC: GamepadButton.c,
          clusterZ: GamepadButton.z,
        ),

        // Shoulders
        GamepadControl(
          id: 'l1',
          type: ControlType.shoulderButton,
          left: 210, // Pixels from left
          bottom: 330, // Pixels from top
          width: 70,
          height: 70,
          buttonMapping: GamepadButton.l1,
        ),
        GamepadControl(
          id: 'l2',
          type: ControlType.shoulderButton,
          left: 270, // Pixels from left
          bottom: 270, // Pixels from top
          width: 70,
          height: 70,
          buttonMapping: GamepadButton.l2,
        ),

        GamepadControl(
          id: 'r1',
          type: ControlType.shoulderButton,
          right: 210, // Pixels from left
          bottom: 330, // Pixels from top
          width: 70,
          height: 70,
          buttonMapping: GamepadButton.r1,
        ),
        GamepadControl(
          id: 'r2',
          type: ControlType.shoulderButton,
          right: 270, // Pixels from left
          bottom: 270, // Pixels from top
          width: 70,
          height: 70,
          buttonMapping: GamepadButton.r2,
        ),

        // Center buttons - can use left or calculate from center
        GamepadControl(
          id: 'select',
          type: ControlType.button,
          centerHorizontal: true,
          offsetX: -60,
          bottom: 180, // Pixels from top
          width: 64,
          height: 40,
          buttonMapping: GamepadButton.select,
        ),
        GamepadControl(
          id: 'start',
          type: ControlType.button,
          centerHorizontal: true,
          offsetX: 60,
          bottom: 180, // Pixels from top
          width: 64,
          height: 40,
          buttonMapping: GamepadButton.start,
        ),
        GamepadControl(
          id: 'mode',
          type: ControlType.button,
          centerHorizontal: true, // Center horizontally
          bottom: 230, // Pixels from bottom
          width: 64,
          height: 40,
          buttonMapping: GamepadButton.home,
        ),
      ],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'controls': controls.map((c) => c.toJson()).toList(),
    };
  }

  factory GamepadLayout.fromJson(Map<String, dynamic> json) {
    return GamepadLayout(
      id: json['id'],
      name: json['name'],
      controls: (json['controls'] as List)
          .map((c) => GamepadControl.fromJson(c))
          .toList(),
    );
  }
}

enum ControlType {
  button,
  joystick,
  dpad,
  buttonCluster,
  shoulderButton,
  trackpad,
}

class GamepadControl {
  final String id;
  final ControlType type;

  // Edge-based positioning in pixels (anchored to CENTER of control)
  double? left; // Distance from left edge to CENTER of control
  double? right; // Distance from right edge to CENTER of control
  double? top; // Distance from top edge to CENTER of control
  double? bottom; // Distance from bottom edge to CENTER of control

  // Centering options
  final bool
  centerHorizontal; // If true, center horizontally and ignore left/right
  final bool centerVertical; // If true, center vertically and ignore top/bottom
  final double
  offsetX; // Horizontal offset from center (when centerHorizontal=true)
  final double
  offsetY; // Vertical offset from center (when centerVertical=true)

  double width;
  double height;

  // Use enum-based mappings instead of raw integers
  final GamepadButton? buttonMapping;
  // Optional Mappings for Button Clusters
  final GamepadButton? clusterBottom;
  final GamepadButton? clusterRight;
  final GamepadButton? clusterLeft;
  final GamepadButton? clusterTop;
  final GamepadButton? clusterC;
  final GamepadButton? clusterZ;

  final Joystick? joystickMapping;

  GamepadControl({
    required this.id,
    required this.type,
    this.left,
    this.right,
    this.top,
    this.bottom,
    this.centerHorizontal = false,
    this.centerVertical = false,
    this.offsetX = 0,
    this.offsetY = 0,
    required this.width,
    required this.height,
    this.buttonMapping,
    this.clusterBottom,
    this.clusterRight,
    this.clusterLeft,
    this.clusterTop,
    this.clusterC,
    this.clusterZ,
    this.joystickMapping,
  }) : assert(
         centerHorizontal || left != null || right != null,
         'Must specify centerHorizontal=true OR provide left or right',
       ),
       assert(
         centerVertical || top != null || bottom != null,
         'Must specify centerVertical=true OR provide top or bottom',
       );

  GamepadControl copyWith({
    String? id,
    ControlType? type,
    double? left,
    double? right,
    double? top,
    double? bottom,
    bool? centerHorizontal,
    bool? centerVertical,
    double? offsetX,
    double? offsetY,
    double? width,
    double? height,
    GamepadButton? buttonMapping,
    GamepadButton? clusterBottom,
    GamepadButton? clusterRight,
    GamepadButton? clusterLeft,
    GamepadButton? clusterTop,
    GamepadButton? clusterC,
    GamepadButton? clusterZ,
    Joystick? joystickMapping,
  }) {
    return GamepadControl(
      id: id ?? this.id,
      type: type ?? this.type,
      left: left ?? this.left,
      right: right ?? this.right,
      top: top ?? this.top,
      bottom: bottom ?? this.bottom,
      centerHorizontal: centerHorizontal ?? this.centerHorizontal,
      centerVertical: centerVertical ?? this.centerVertical,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      width: width ?? this.width,
      height: height ?? this.height,
      buttonMapping: buttonMapping ?? this.buttonMapping,
      clusterBottom: clusterBottom ?? this.clusterBottom,
      clusterRight: clusterRight ?? this.clusterRight,
      clusterLeft: clusterLeft ?? this.clusterLeft,
      clusterTop: clusterTop ?? this.clusterTop,
      clusterC: clusterC ?? this.clusterC,
      clusterZ: clusterZ ?? this.clusterZ,
      joystickMapping: joystickMapping ?? this.joystickMapping,
    );
  }

  // Get button label from descriptor
  String getLabel(GamepadDescriptor descriptor) {
    if (buttonMapping != null) {
      return descriptor.getButtonLabel(buttonMapping!);
    }
    return id.toUpperCase();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'left': left,
      'right': right,
      'top': top,
      'bottom': bottom,
      'centerHorizontal': centerHorizontal,
      'centerVertical': centerVertical,
      'offsetX': offsetX,
      'offsetY': offsetY,
      'width': width,
      'height': height,
      'buttonMapping': buttonMapping?.index,
      'clusterBottom': clusterBottom?.index,
      'clusterRight': clusterRight?.index,
      'clusterLeft': clusterLeft?.index,
      'clusterTop': clusterTop?.index,
      'clusterC': clusterC?.index,
      'clusterZ': clusterZ?.index,
      'joystickMapping': joystickMapping?.index,
    };
  }

  factory GamepadControl.fromJson(Map<String, dynamic> json) {
    return GamepadControl(
      id: json['id'],
      type: ControlType.values[json['type']],
      left: json['left'],
      right: json['right'],
      top: json['top'],
      bottom: json['bottom'],
      centerHorizontal: json['centerHorizontal'] ?? false,
      centerVertical: json['centerVertical'] ?? false,
      offsetX: json['offsetX'] ?? 0,
      offsetY: json['offsetY'] ?? 0,
      width: json['width'],
      height: json['height'],
      buttonMapping: json['buttonMapping'] != null
          ? GamepadButton.values[json['buttonMapping']]
          : null,
      clusterBottom: json['clusterBottom'] != null
          ? GamepadButton.values[json['clusterBottom']]
          : null,
      clusterRight: json['clusterRight'] != null
          ? GamepadButton.values[json['clusterRight']]
          : null,
      clusterLeft: json['clusterLeft'] != null
          ? GamepadButton.values[json['clusterLeft']]
          : null,
      clusterTop: json['clusterTop'] != null
          ? GamepadButton.values[json['clusterTop']]
          : null,
      clusterC: json['clusterC'] != null
          ? GamepadButton.values[json['clusterC']]
          : null,
      clusterZ: json['clusterZ'] != null
          ? GamepadButton.values[json['clusterZ']]
          : null,
      joystickMapping: json['joystickMapping'] != null
          ? Joystick.values[json['joystickMapping']]
          : null,
    );
  }
}
