import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/gamepad_descriptor.dart';

class BluetoothGamepadService {
  static const MethodChannel _channel = MethodChannel(
    'com.sn.agamepad/gamepad',
  );

  // Singleton
  static final BluetoothGamepadService _instance =
      BluetoothGamepadService._internal();
  factory BluetoothGamepadService() => _instance;

  BluetoothGamepadService._internal() {
    if (kDebugMode) {
      debugPrint('[BluetoothGamepadService] Initializing service...');
    }
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  bool _isInitialized = false;
  
  // Keepalive mechanism to prevent Bluetooth sniff mode latency
  Timer? _keepaliveTimer;
  Uint8List? _lastReport;
  static const _keepaliveIntervalMs = 50; // Send every 50ms when active

  // Streams
  final _connectionStateController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get connectionStateStream =>
      _connectionStateController.stream;

  final _appStatusController = StreamController<bool>.broadcast();
  Stream<bool> get appStatusStream => _appStatusController.stream;

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onConnectionStateChanged':
        if (call.arguments is Map) {
          final args = Map<String, dynamic>.from(call.arguments);
          if (kDebugMode) {
            debugPrint(
              '[BluetoothGamepadService] Connection state changed: $args',
            );
          }
          _connectionStateController.add(args);
        }
        break;
      case 'onAppStatusChanged':
        if (call.arguments is Map) {
          final registered = call.arguments['registered'] == true;
          if (kDebugMode) {
            debugPrint(
              '[BluetoothGamepadService] App status changed: registered=$registered',
            );
          }
          // Note: We don't reset _isInitialized here because during mode switches,
          // the old service's unregister happens after the new service's register,
          // which would incorrectly clear the flag. Only stop() should reset it.
          _appStatusController.add(registered);
        }
        break;
      default:
        if (kDebugMode) {
          debugPrint(
            '[BluetoothGamepadService] Unknown method call: ${call.method}',
          );
        }
    }
  }

  /// Initialize the gamepad service
  /// [mode] can be 'classic' for Classic Bluetooth HID or 'ble' for BLE HID
  Future<void> initialize({String mode = 'classic'}) async {
    try {
      if (kDebugMode) {
        debugPrint('[BluetoothGamepadService] Calling native initialize() with mode: $mode...');
      }
      await _channel.invokeMethod('initialize', {
        'descriptor': Uint8List.fromList(GamepadDescriptor.reportDescriptor),
        'mode': mode,
      });
      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('[BluetoothGamepadService] Initialize successful');
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint(
          "[BluetoothGamepadService] Failed to initialize gamepad: '${e.message}'. Code: ${e.code}",
        );
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          "[BluetoothGamepadService] Unexpected error during initialize: $e",
        );
      }
      rethrow;
    }
  }

  /// Set the Bluetooth mode (classic or ble)
  /// Note: This only stores the preference, you need to call initialize() to apply
  Future<void> setMode(String mode) async {
    try {
      await _channel.invokeMethod('setMode', {'mode': mode});
      if (kDebugMode) {
        debugPrint('[BluetoothGamepadService] Mode set to: $mode');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BluetoothGamepadService] Error setting mode: $e');
      }
    }
  }

  /// Get the current Bluetooth mode
  Future<String> getMode() async {
    try {
      final String? mode = await _channel.invokeMethod('getMode');
      return mode ?? 'classic';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BluetoothGamepadService] Error getting mode: $e');
      }
      return 'classic';
    }
  }

  Future<void> stop() async {
    try {
      if (kDebugMode) {
        debugPrint('[BluetoothGamepadService] Calling native stop()...');
      }
      await _channel.invokeMethod('stop');
      _isInitialized = false;
      if (kDebugMode) debugPrint('[BluetoothGamepadService] Stop successful');
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint(
          "[BluetoothGamepadService] Failed to stop gamepad: '${e.message}'. Code: ${e.code}",
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          "[BluetoothGamepadService] Unexpected error during stop: $e",
        );
      }
    }
  }

  Future<List<Map<String, String>>> getPairedDevices() async {
    try {
      debugPrint(
        '[BluetoothGamepadService] Calling native getPairedDevices()...',
      );
      final result = await _channel.invokeMethod('getPairedDevices');
      if (result is List) {
        final devices = result.map((e) => Map<String, String>.from(e)).toList();
        debugPrint(
          '[BluetoothGamepadService] getPairedDevices returned ${devices.length} devices',
        );
        return devices;
      }
      debugPrint(
        '[BluetoothGamepadService] getPairedDevices returned empty/invalid result',
      );
      return [];
    } on PlatformException catch (e) {
      debugPrint(
        "[BluetoothGamepadService] Failed to get paired devices: '${e.message}'. Code: ${e.code}",
      );
      return [];
    } catch (e) {
      debugPrint(
        "[BluetoothGamepadService] Unexpected error during getPairedDevices: $e",
      );
      return [];
    }
  }

  Future<void> connect(String address) async {
    try {
      debugPrint(
        '[BluetoothGamepadService] Calling native connect() for address: $address',
      );
      await _channel.invokeMethod('connect', {'address': address});
      debugPrint(
        '[BluetoothGamepadService] Connect call completed for: $address',
      );
    } on PlatformException catch (e) {
      debugPrint(
        "[BluetoothGamepadService] Failed to connect: '${e.message}'. Code: ${e.code}",
      );
    } catch (e) {
      debugPrint(
        "[BluetoothGamepadService] Unexpected error during connect: $e",
      );
    }
  }

  Future<void> disconnect(String address) async {
    try {
      debugPrint(
        '[BluetoothGamepadService] Calling native disconnect() for address: $address',
      );
      await _channel.invokeMethod('disconnect', {'address': address});
      debugPrint(
        '[BluetoothGamepadService] Disconnect call completed for: $address',
      );
    } on PlatformException catch (e) {
      debugPrint(
        "[BluetoothGamepadService] Failed to disconnect: '${e.message}'. Code: ${e.code}",
      );
    } catch (e) {
      debugPrint(
        "[BluetoothGamepadService] Unexpected error during disconnect: $e",
      );
    }
  }

  void sendInput({
    required int buttons, // Bitmask of buttons
    required int lx, // 0-255, 127 is center
    required int ly, // 0-255, 127 is center
    required int rx, // 0-255, 127 is center
    required int ry, // 0-255, 127 is center
    required int dpad, // Hat switch value (0-8)
  }) {
    if (!_isInitialized) return;

    // Create report with Report ID prefix
    // The HID descriptor declares Report ID 1, so reports must include it
    final report = Uint8List(8);
    report[0] = 0x01; // Report ID 1
    report[1] = lx;
    report[2] = ly;
    report[3] = rx;
    report[4] = ry;
    report[5] = buttons & 0xFF;
    report[6] = (buttons >> 8) & 0xFF;
    report[7] = dpad;

    // Store for keepalive
    _lastReport = report;

    // Use BinaryMessages for the absolute lowest latency (direct byte transfer)
    // We don't await here to avoid blocking the UI thread during high-frequency moves
    _sendRawReport(report);
  }

  void _sendRawReport(Uint8List report) {
    ServicesBinding.instance.defaultBinaryMessenger.send(
      'com.sn.agamepad/gamepad/raw',
      report.buffer.asByteData(),
    );
  }

  /// Start keepalive to prevent Bluetooth sniff mode latency.
  /// Call this when entering the gamepad screen.
  void startKeepalive() {
    stopKeepalive(); // Cancel any existing timer
    
    // Initialize with neutral state if no report exists (includes Report ID 1)
    _lastReport ??= Uint8List.fromList([0x01, 127, 127, 127, 127, 0, 0, 8]);
    
    _keepaliveTimer = Timer.periodic(
      const Duration(milliseconds: _keepaliveIntervalMs),
      (_) {
        if (_isInitialized && _lastReport != null) {
          _sendRawReport(_lastReport!);
        }
      },
    );
    
    if (kDebugMode) {
      debugPrint('[BluetoothGamepadService] Keepalive started (${_keepaliveIntervalMs}ms interval)');
    }
  }

  /// Stop keepalive. Call this when leaving the gamepad screen.
  void stopKeepalive() {
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
    if (kDebugMode) {
      debugPrint('[BluetoothGamepadService] Keepalive stopped');
    }
  }

  Future<bool> setBluetoothName(String name) async {
    try {
      final result = await _channel.invokeMethod('setBluetoothName', {
        'name': name,
      });
      return result == true;
    } catch (e) {
      debugPrint('[BluetoothGamepadService] Error setting name: $e');
      return false;
    }
  }

  Future<String> getBluetoothName() async {
    try {
      final String? name = await _channel.invokeMethod('getBluetoothName');
      return name ?? "Unknown";
    } catch (e) {
      debugPrint('[BluetoothGamepadService] Error getting name: $e');
      return "Unknown";
    }
  }

  Future<void> requestDiscoverable({int duration = 300}) async {
    try {
      await _channel.invokeMethod('requestDiscoverable', {
        'duration': duration,
      });
    } catch (e) {
      debugPrint('[BluetoothGamepadService] Error requesting discoverable: $e');
    }
  }
}
