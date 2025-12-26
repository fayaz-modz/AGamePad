import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/gamepad_descriptor.dart';

class BluetoothGamepadService {
  static const MethodChannel _channel = MethodChannel('com.sn.agamepad/gamepad');
  
  // Singleton
  static final BluetoothGamepadService _instance = BluetoothGamepadService._internal();
  factory BluetoothGamepadService() => _instance;
  
  BluetoothGamepadService._internal() {
    debugPrint('[BluetoothGamepadService] Initializing service...');
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  bool _isInitialized = false;
  
  // Streams
  final _connectionStateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get connectionStateStream => _connectionStateController.stream;
  
  final _appStatusController = StreamController<bool>.broadcast();
  Stream<bool> get appStatusStream => _appStatusController.stream;

  Future<void> _handleMethodCall(MethodCall call) async {
    debugPrint('[BluetoothGamepadService] Method call from native: ${call.method}');
    switch (call.method) {
      case 'onConnectionStateChanged':
        if (call.arguments is Map) {
           final args = Map<String, dynamic>.from(call.arguments);
           debugPrint('[BluetoothGamepadService] Connection state changed: $args');
           _connectionStateController.add(args);
        }
        break;
      case 'onAppStatusChanged':
        if (call.arguments is Map) {
           final registered = call.arguments['registered'] == true;
           debugPrint('[BluetoothGamepadService] App status changed: registered=$registered');
           if (!registered) {
             // When unregistered, allow re-initialization
             _isInitialized = false;
             debugPrint('[BluetoothGamepadService] Reset _isInitialized flag due to unregistration');
           }
           _appStatusController.add(registered);
        }
        break;
      default:
        debugPrint('[BluetoothGamepadService] Unknown method call: ${call.method}');
    }
  }

  Future<void> initialize() async {
    try {
      debugPrint('[BluetoothGamepadService] Calling native initialize()...');
      await _channel.invokeMethod('initialize', {
        'descriptor': Uint8List.fromList(GamepadDescriptor.reportDescriptor),
      });
      _isInitialized = true;
      debugPrint('[BluetoothGamepadService] Initialize successful');
    } on PlatformException catch (e) {
      debugPrint("[BluetoothGamepadService] Failed to initialize gamepad: '${e.message}'. Code: ${e.code}");
      rethrow;
    } catch (e) {
      debugPrint("[BluetoothGamepadService] Unexpected error during initialize: $e");
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
      debugPrint('[BluetoothGamepadService] Calling native stop()...');
      await _channel.invokeMethod('stop');
      _isInitialized = false;
      debugPrint('[BluetoothGamepadService] Stop successful');
    } on PlatformException catch (e) {
      debugPrint("[BluetoothGamepadService] Failed to stop gamepad: '${e.message}'. Code: ${e.code}");
    } catch (e) {
      debugPrint("[BluetoothGamepadService] Unexpected error during stop: $e");
    }
  }
  
  Future<List<Map<String, String>>> getPairedDevices() async {
    try {
      debugPrint('[BluetoothGamepadService] Calling native getPairedDevices()...');
      final result = await _channel.invokeMethod('getPairedDevices');
      if (result is List) {
        final devices = result.map((e) => Map<String, String>.from(e)).toList();
        debugPrint('[BluetoothGamepadService] getPairedDevices returned ${devices.length} devices');
        return devices;
      }
      debugPrint('[BluetoothGamepadService] getPairedDevices returned empty/invalid result');
      return [];
    } on PlatformException catch (e) {
      debugPrint("[BluetoothGamepadService] Failed to get paired devices: '${e.message}'. Code: ${e.code}");
      return [];
    } catch (e) {
      debugPrint("[BluetoothGamepadService] Unexpected error during getPairedDevices: $e");
      return [];
    }
  }

  Future<void> connect(String address) async {
    try {
       debugPrint('[BluetoothGamepadService] Calling native connect() for address: $address');
       await _channel.invokeMethod('connect', {'address': address});
       debugPrint('[BluetoothGamepadService] Connect call completed for: $address');
    } on PlatformException catch (e) {
       debugPrint("[BluetoothGamepadService] Failed to connect: '${e.message}'. Code: ${e.code}");
    } catch (e) {
       debugPrint("[BluetoothGamepadService] Unexpected error during connect: $e");
    }
  }

  Future<void> disconnect(String address) async {
    try {
       debugPrint('[BluetoothGamepadService] Calling native disconnect() for address: $address');
       await _channel.invokeMethod('disconnect', {'address': address});
       debugPrint('[BluetoothGamepadService] Disconnect call completed for: $address');
    } on PlatformException catch (e) {
       debugPrint("[BluetoothGamepadService] Failed to disconnect: '${e.message}'. Code: ${e.code}");
    } catch (e) {
       debugPrint("[BluetoothGamepadService] Unexpected error during disconnect: $e");
    }
  }

  Future<void> sendInput({
    required int buttons, // Bitmask of buttons
    required int lx,      // 0-255, 127 is center
    required int ly,      // 0-255, 127 is center
    required int rx,      // 0-255, 127 is center
    required int ry,      // 0-255, 127 is center
    required int dpad,    // Hat switch value (0-8)
  }) async {
    if (!_isInitialized) return;
    try {
      await _channel.invokeMethod('sendInput', {
        'buttons': buttons,
        'lx': lx,
        'ly': ly,
        'rx': rx,
        'ry': ry,
        'dpad': dpad,
      });
    } on PlatformException {
      // Silently ignore errors during input sending to avoid log spam
    }
  }
}
