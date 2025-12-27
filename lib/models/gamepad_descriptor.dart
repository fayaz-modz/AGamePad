// Standard HID Gamepad Button Definitions
enum GamepadButton {
  // Face buttons
  button1,
  button2,
  button3,
  button4,
  
  // Shoulder buttons
  l1,
  r1,
  l2,
  r2,
  
  // Center buttons
  select,
  start,
  
  // Stick buttons
  l3,
  r3,
  
  // Special buttons
  c,
  z,
  home,
  touchpad,
}

// D-pad directions
enum DPadDirection {
  center,
  up,
  upRight,
  right,
  downRight,
  down,
  downLeft,
  left,
  upLeft,
}

// Joystick identifiers
enum Joystick {
  left,
  right,
}

// Generic gamepad descriptor that maps logical buttons to physical HID report bits
class GamepadDescriptor {
  // Singleton instance
  static final GamepadDescriptor _instance = GamepadDescriptor._internal();
  factory GamepadDescriptor() => _instance;
  GamepadDescriptor._internal();
  
  String get name => 'Generic Gamepad';
  
  // Map logical button to bit position in HID report
  int getButtonBit(GamepadButton button) {
    // Standard HID gamepad button mapping (bit positions)
    switch (button) {
      case GamepadButton.button1: // A (CROSS)
        return 0;  // 0x01
      case GamepadButton.button2: // B (CIRCLE)
        return 1;  // 0x02
      case GamepadButton.c:       // C
        return 2;  // 0x04
      case GamepadButton.button3: // X (SQUARE)
        return 3;  // 0x08
      case GamepadButton.button4: // Y (TRIANGLE)
        return 4;  // 0x10
      case GamepadButton.z:       // Z
        return 5;  // 0x20
      case GamepadButton.l1:
        return 6;  // 0x40
      case GamepadButton.r1:
        return 7;  // 0x80
      case GamepadButton.l2:
        return 8;  // 0x100
      case GamepadButton.r2:
        return 9;  // 0x200
      case GamepadButton.select:
        return 10; // 0x400
      case GamepadButton.start:
        return 11; // 0x800
      case GamepadButton.home: // MODE
        return 12; // 0x1000
      case GamepadButton.l3: // THUMBL
        return 13; // 0x2000
      case GamepadButton.r3: // THUMBR
        return 14; // 0x4000
      case GamepadButton.touchpad:
        return 15; // 0x8000
    }
  }
  
  // Map d-pad direction to HID hat switch value
  int getDPadValue(DPadDirection direction) {
    // Standard Hat switch values: 0 = Up, 1 = UpRight... 7 = UpLeft, 8 = Null (Center)
    switch (direction) {
      case DPadDirection.center:
        return 8; // Null State
      case DPadDirection.up:
        return 0;
      case DPadDirection.upRight:
        return 1;
      case DPadDirection.right:
        return 2;
      case DPadDirection.downRight:
        return 3;
      case DPadDirection.down:
        return 4;
      case DPadDirection.downLeft:
        return 5;
      case DPadDirection.left:
        return 6;
      case DPadDirection.upLeft:
        return 7;
    }
  }
  
  // Get button label for UI display
  String getButtonLabel(GamepadButton button) {
    switch (button) {
      case GamepadButton.button1:
        return 'A'; // or CROSS
      case GamepadButton.button2:
        return 'B'; // or CIRCLE
      case GamepadButton.c:
        return 'C';
      case GamepadButton.button3:
        return 'X'; // or SQUARE
      case GamepadButton.button4:
        return 'Y'; // or TRIANGLE
      case GamepadButton.z:
        return 'Z';
      case GamepadButton.l1:
        return 'L1';
      case GamepadButton.r1:
        return 'R1';
      case GamepadButton.l2:
        return 'L2';
      case GamepadButton.r2:
        return 'R2';
      case GamepadButton.select:
        return 'SELECT';
      case GamepadButton.start:
        return 'START';
      case GamepadButton.l3:
        return 'L3';
      case GamepadButton.r3:
        return 'R3';
      case GamepadButton.home:
        return 'MODE';
      case GamepadButton.touchpad:
        return 'EXTRA';
    }
  }
  // HID Report Descriptor
  static const List<int> reportDescriptor = [
    0x05, 0x01,       // Usage Page (Generic Desktop Ctrls)
    0x09, 0x05,       // Usage (Gamepad)
    0xA1, 0x01,       // Collection (Application)
    0x85, 0x01,       //   Report ID (1)
    
    // Joystick Axes (Left Stick: X,Y; Right Stick: Z,Rz)
    0x05, 0x01,       //   Usage Page (Generic Desktop Ctrls)
    0x09, 0x01,       //   Usage (Pointer)
    0xA1, 0x00,       //   Collection (Physical)
    0x09, 0x30,       //     Usage (X)
    0x09, 0x31,       //     Usage (Y)
    0x09, 0x32,       //     Usage (Z)
    0x09, 0x35,       //     Usage (Rz)
    0x15, 0x00,       //     Logical Minimum (0)
    0x26, 0xFF, 0x00, //     Logical Maximum (255)
    0x75, 0x08,       //     Report Size (8)
    0x95, 0x04,       //     Report Count (4)
    0x81, 0x02,       //     Input (Data,Var,Abs,No Wrap,Linear,Preferred State,No Null Position)
    0xC0,             //   End Collection
    
    // Buttons (16 buttons)
    0x05, 0x09,       //   Usage Page (Button)
    0x19, 0x01,       //   Usage Minimum (0x01)
    0x29, 0x10,       //   Usage Maximum (0x10)
    0x15, 0x00,       //   Logical Minimum (0)
    0x25, 0x01,       //   Logical Maximum (1)
    0x75, 0x01,       //   Report Size (1)
    0x95, 0x10,       //   Report Count (16)
    0x81, 0x02,       //   Input (Data,Var,Abs,No Wrap,Linear,Preferred State,No Null Position)
    
    // D-Pad (Hat Switch)
    0x05, 0x01,       //   Usage Page (Generic Desktop Ctrls)
    0x09, 0x39,       //   Usage (Hat switch)
    0x15, 0x00,       //   Logical Minimum (0)
    0x25, 0x07,       //   Logical Maximum (7)
    0x75, 0x08,       //   Report Size (8)
    0x95, 0x01,       //   Report Count (1)
    0x81, 0x42,       //   Input (Data,Var,Abs,No Wrap,Linear,Preferred State,Null State)
    
    0xC0              // End Collection
  ];

  // UDP Report Descriptor - Enhanced layout for Android/Linux compatibility
  // Axes: X, Y, Z (L2), Rx (Right X), Ry (Right Y), Rz (R2)
  static const List<int> udpReportDescriptor = [
    0x05, 0x01,       // Usage Page (Generic Desktop Ctrls)
    0x09, 0x05,       // Usage (Gamepad)
    0xA1, 0x01,       // Collection (Application)
    0x85, 0x01,       //   Report ID (1)
    
    // Axes (6 axes: X, Y, Z, Rx, Ry, Rz) - Sequential Order [0x30..0x35]
    // Matches DS4 style mapping: 0x32/0x35 for RS, 0x33/0x34 for Triggers
    0x05, 0x01,       //   Usage Page (Generic Desktop Ctrls)
    0x09, 0x01,       //   Usage (Pointer)
    0xA1, 0x00,       //   Collection (Physical)
    0x09, 0x30,       //     Usage (X)  -> Left Stick X
    0x09, 0x31,       //     Usage (Y)  -> Left Stick Y
    0x09, 0x32,       //     Usage (Z)  -> Right Stick X
    0x09, 0x33,       //     Usage (Rx) -> L2 Trigger
    0x09, 0x34,       //     Usage (Ry) -> R2 Trigger
    0x09, 0x35,       //     Usage (Rz) -> Right Stick Y
    0x15, 0x00,       //     Logical Minimum (0)
    0x26, 0xFF, 0x00, //     Logical Maximum (255)
    0x75, 0x08,       //     Report Size (8)
    0x95, 0x06,       //     Report Count (6) - 6 bytes for 6 axes
    0x81, 0x02,       //     Input (Data,Var,Abs,No Wrap,Linear,Preferred State,No Null Position)
    0xC0,             //   End Collection
    
    // Buttons (16 buttons)
    0x05, 0x09,       //   Usage Page (Button)
    0x19, 0x01,       //   Usage Minimum (0x01)
    0x29, 0x10,       //   Usage Maximum (0x10)
    0x15, 0x00,       //   Logical Minimum (0)
    0x25, 0x01,       //   Logical Maximum (1)
    0x75, 0x01,       //   Report Size (1)
    0x95, 0x10,       //   Report Count (16)
    0x81, 0x02,       //   Input (Data,Var,Abs,No Wrap,Linear,Preferred State,No Null Position)
    
    // D-Pad (Hat Switch)
    0x05, 0x01,       //   Usage Page (Generic Desktop Ctrls)
    0x09, 0x39,       //   Usage (Hat switch)
    0x15, 0x00,       //   Logical Minimum (0)
    0x25, 0x07,       //   Logical Maximum (7)
    0x75, 0x08,       //   Report Size (8)
    0x95, 0x01,       //   Report Count (1)
    0x81, 0x42,       //   Input (Data,Var,Abs,No Wrap,Linear,Preferred State,Null State)
    
    0xC0              // End Collection
  ];

}

// Helper class to build button bitmask
class ButtonMaskBuilder {
  int _mask = 0;
  final GamepadDescriptor descriptor;
  
  ButtonMaskBuilder(this.descriptor);
  
  void press(GamepadButton button) {
    final bit = descriptor.getButtonBit(button);
    if (bit >= 0) {
      _mask |= (1 << bit);
    }
  }
  
  void release(GamepadButton button) {
    final bit = descriptor.getButtonBit(button);
    if (bit >= 0) {
      _mask &= ~(1 << bit);
    }
  }
  
  int get mask => _mask;
  
  void clear() {
    _mask = 0;
  }
  
  void setMask(int mask) {
    _mask = mask;
  }
}
