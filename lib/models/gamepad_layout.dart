import 'gamepad_descriptor.dart';

class GamepadLayout {
  final String id;
  final String name;
  final List<GamepadControl> controls;

  GamepadLayout({
    required this.id,
    required this.name,
    required this.controls,
  });

  static GamepadLayout xbox() {
    return GamepadLayout(
      id: 'xbox_default',
      name: 'Xbox Style',
      controls: [
        // Left side controls
        GamepadControl(
          id: 'l_joystick',
          type: ControlType.joystick,
          x: 0.10,
          y: 0.60,
          width: 0.28,
          height: 0.28,
          joystickMapping: Joystick.left,
        ),
        GamepadControl(
          id: 'dpad',
          type: ControlType.dpad,
          x: 0.05,
          y: 0.25,
          width: 0.30,
          height: 0.30,
        ),
        
        // Right side controls
        GamepadControl(
          id: 'r_joystick',
          type: ControlType.joystick,
          x: 0.62,
          y: 0.60,
          width: 0.28,
          height: 0.28,
          joystickMapping: Joystick.right,
        ),
        GamepadControl(
          id: 'abxy',
          type: ControlType.buttonCluster,
          x: 0.65,
          y: 0.25,
          width: 0.30,
          height: 0.30,
          // Xbox Standard: A-Bottom, B-Right, X-Left, Y-Top
          clusterBottom: GamepadButton.button1,
          clusterRight: GamepadButton.button2,
          clusterLeft: GamepadButton.button3,
          clusterTop: GamepadButton.button4,
        ),
        
        // Shoulder buttons/Triggers
        // Left
        GamepadControl(
          id: 'l2',
          type: ControlType.shoulderButton,
          x: 0.02,
          y: 0.02,
          width: 0.18,
          height: 0.08,
          buttonMapping: GamepadButton.l2,
        ),
        GamepadControl(
          id: 'l1',
          type: ControlType.shoulderButton,
          x: 0.02,
          y: 0.11,
          width: 0.18,
          height: 0.08,
          buttonMapping: GamepadButton.l1,
        ),
        
        // Right
        GamepadControl(
          id: 'r2',
          type: ControlType.shoulderButton,
          x: 0.80,
          y: 0.02,
          width: 0.18,
          height: 0.08,
          buttonMapping: GamepadButton.r2,
        ),
        GamepadControl(
          id: 'r1',
          type: ControlType.shoulderButton,
          x: 0.80,
          y: 0.11,
          width: 0.18,
          height: 0.08,
          buttonMapping: GamepadButton.r1,
        ),
        
        // Center buttons
        GamepadControl(
          id: 'select',
          type: ControlType.button,
          x: 0.40,
          y: 0.45,
          width: 0.08,
          height: 0.08,
          buttonMapping: GamepadButton.select,
        ),
        GamepadControl(
          id: 'start',
          type: ControlType.button,
          x: 0.52,
          y: 0.45,
          width: 0.08,
          height: 0.08,
          buttonMapping: GamepadButton.start,
        ),
        GamepadControl(
          id: 'home',
          type: ControlType.button,
          x: 0.46,
          y: 0.30,
          width: 0.08,
          height: 0.08,
          buttonMapping: GamepadButton.home,
        ),

        // Stick Buttons
        GamepadControl(
          id: 'l3',
          type: ControlType.button,
          x: 0.42,
          y: 0.70,
          width: 0.08,
          height: 0.08,
          buttonMapping: GamepadButton.l3,
        ),
        GamepadControl(
          id: 'r3',
          type: ControlType.button,
          x: 0.50,
          y: 0.70,
          width: 0.08,
          height: 0.08,
          buttonMapping: GamepadButton.r3,
        ),
      ],
    );
  }

  static GamepadLayout android() {
     return GamepadLayout(
      id: 'android_default',
      name: 'Android Layout',
      controls: [
        // Left side
        GamepadControl(
          id: 'l_joystick',
          type: ControlType.joystick,
          x: 0.10,
          y: 0.50,
          width: 0.28,
          height: 0.28,
          joystickMapping: Joystick.left,
        ),
        GamepadControl(
          id: 'dpad',
          type: ControlType.dpad,
          x: 0.05,
          y: 0.15,
          width: 0.30,
          height: 0.30,
        ),
        
        // Right side
        GamepadControl(
          id: 'r_joystick',
          type: ControlType.joystick,
          x: 0.62,
          y: 0.50,
          width: 0.28,
          height: 0.28,
          joystickMapping: Joystick.right,
        ),
        GamepadControl(
          id: 'abxycz',
          type: ControlType.buttonCluster,
          x: 0.65,
          y: 0.10,
          width: 0.35,
          height: 0.35,
          // Android Mapping: Standard 6-button cluster
          clusterBottom: GamepadButton.button1, // A
          clusterRight: GamepadButton.button2,  // B
          clusterLeft: GamepadButton.button3,   // X
          clusterTop: GamepadButton.button4,    // Y
          clusterC: GamepadButton.c,            // C
          clusterZ: GamepadButton.z,            // Z
        ),
        
        // Shoulders
        GamepadControl(
          id: 'l1',
          type: ControlType.shoulderButton,
          x: 0.02,
          y: 0.02,
          width: 0.15,
          height: 0.08,
          buttonMapping: GamepadButton.l1,
        ),
        GamepadControl(
          id: 'l2',
          type: ControlType.shoulderButton,
          x: 0.02,
          y: 0.11,
          width: 0.15,
          height: 0.08,
          buttonMapping: GamepadButton.l2,
        ),
        
        GamepadControl(
          id: 'r1',
          type: ControlType.shoulderButton,
          x: 0.83,
          y: 0.02,
          width: 0.15,
          height: 0.08,
          buttonMapping: GamepadButton.r1,
        ),
        GamepadControl(
          id: 'r2',
          type: ControlType.shoulderButton,
          x: 0.83,
          y: 0.11,
          width: 0.15,
          height: 0.08,
          buttonMapping: GamepadButton.r2,
        ),
        
        // Center - Stuck to bottom edge
        GamepadControl(
          id: 'select', 
          type: ControlType.button,
          x: 0.38, y: 0.90, width: 0.08, height: 0.08,
          buttonMapping: GamepadButton.select,
        ),
        GamepadControl(
          id: 'start', 
          type: ControlType.button,
          x: 0.54, y: 0.90, width: 0.08, height: 0.08,
          buttonMapping: GamepadButton.start,
        ),
        GamepadControl(
          id: 'mode', 
          type: ControlType.button,
          x: 0.46, y: 0.80, width: 0.08, height: 0.08,
          buttonMapping: GamepadButton.home, // Mode/Home
        ),
        
        // Stick Buttons (L3/R3)
        GamepadControl(
          id: 'l3',
          type: ControlType.button,
          x: 0.38, y: 0.60, width: 0.08, height: 0.08,
          buttonMapping: GamepadButton.l3,
        ),
        GamepadControl(
          id: 'r3',
          type: ControlType.button,
          x: 0.54, y: 0.60, width: 0.08, height: 0.08,
          buttonMapping: GamepadButton.r3,
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
      controls: (json['controls'] as List).map((c) => GamepadControl.fromJson(c)).toList(),
    );
  }
}

enum ControlType { button, joystick, dpad, buttonCluster, shoulderButton }

class GamepadControl {
  final String id;
  final ControlType type;
  double x; // 0.0-1.0
  double y; // 0.0-1.0
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
    required this.x,
    required this.y,
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
  });
  
  GamepadControl copyWith({
    String? id,
    ControlType? type,
    double? x,
    double? y,
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
      x: x ?? this.x,
      y: y ?? this.y,
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
      'x': x,
      'y': y,
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
      x: json['x'],
      y: json['y'],
      width: json['width'],
      height: json['height'],
      buttonMapping: json['buttonMapping'] != null 
          ? GamepadButton.values[json['buttonMapping']]
          : null,
      clusterBottom: json['clusterBottom'] != null ? GamepadButton.values[json['clusterBottom']] : null,
      clusterRight: json['clusterRight'] != null ? GamepadButton.values[json['clusterRight']] : null,
      clusterLeft: json['clusterLeft'] != null ? GamepadButton.values[json['clusterLeft']] : null,
      clusterTop: json['clusterTop'] != null ? GamepadButton.values[json['clusterTop']] : null,
      clusterC: json['clusterC'] != null ? GamepadButton.values[json['clusterC']] : null,
      clusterZ: json['clusterZ'] != null ? GamepadButton.values[json['clusterZ']] : null,
      joystickMapping: json['joystickMapping'] != null
          ? Joystick.values[json['joystickMapping']]
          : null,
    );
  }
}
