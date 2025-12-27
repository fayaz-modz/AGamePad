import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/bluetooth_gamepad_service.dart';

/// Bluetooth mode options
enum BluetoothMode {
  /// Classic Bluetooth HID - Lower latency, shows as phone during discovery
  classic,
  /// BLE HID - Higher latency (~15-30ms more), shows as gamepad during discovery
  ble,
}

class ConnectionProvider with ChangeNotifier {
  final BluetoothGamepadService _service = BluetoothGamepadService();
  
  bool _isAdvertising = false;
  bool get isAdvertising => _isAdvertising;

  bool _isConnected = false;
  bool get isConnected => _isConnected;
  
  String? _connectedDeviceAddress;
  String? get connectedDeviceAddress => _connectedDeviceAddress;

  String _deviceName = "Unknown";
  String get deviceName => _deviceName;

  List<Map<String, String>> _pairedDevices = [];
  List<Map<String, String>> get pairedDevices => _pairedDevices;

  // Bluetooth mode: classic or ble
  BluetoothMode _bluetoothMode = BluetoothMode.classic;
  BluetoothMode get bluetoothMode => _bluetoothMode;

  ConnectionProvider() {
     debugPrint('[ConnectionProvider] Initializing ConnectionProvider...');
     _service.appStatusStream.listen((registered) {
       debugPrint('[ConnectionProvider] App status changed: registered=$registered');
       _isAdvertising = registered;
       notifyListeners();
     });
     _service.connectionStateStream.listen((event) {
        final state = event['state'];
        final address = event['address'];
        debugPrint('[ConnectionProvider] Connection state changed: state=$state, address=$address');
        // state 2 is Connected, 0 is Disconnected, 1 is Connecting, 3 is Disconnecting (Standard Android BluetoothProfile states)
        if (state == 2) {
          debugPrint('[ConnectionProvider] Device connected: $address');
          _isConnected = true;
          _connectedDeviceAddress = address;
        } else if (state == 0) {
          debugPrint('[ConnectionProvider] Device disconnected: $address');
          _isConnected = false;
          _connectedDeviceAddress = null;
        } else if (state == 1) {
          debugPrint('[ConnectionProvider] Device connecting: $address');
        } else if (state == 3) {
          debugPrint('[ConnectionProvider] Device disconnecting: $address');
        }
        notifyListeners();
     });
     debugPrint('[ConnectionProvider] Setting up initial state...');
     refreshPairedDevices();
     _loadDeviceName();
     _loadBluetoothMode();
  }

  Future<void> _loadDeviceName() async {
    _deviceName = await _service.getBluetoothName();
    notifyListeners();
  }

  static const _bluetoothModeKey = 'bluetooth_mode';

  Future<void> _loadBluetoothMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeString = prefs.getString(_bluetoothModeKey);
      _bluetoothMode = modeString == 'ble' ? BluetoothMode.ble : BluetoothMode.classic;
      // Also set the mode on the native side
      await _service.setMode(modeString ?? 'classic');
      debugPrint('[ConnectionProvider] Loaded Bluetooth mode: $_bluetoothMode');
    } catch (e) {
      debugPrint('[ConnectionProvider] Error loading Bluetooth mode: $e');
    }
    notifyListeners();
  }

  Future<void> setBluetoothName(String name) async {
    final success = await _service.setBluetoothName(name);
    if (success) {
      _deviceName = name;
      notifyListeners();
    }
  }

  /// Set the Bluetooth mode (classic or ble)
  /// If advertising is active, it will be restarted with the new mode
  Future<void> setBluetoothMode(BluetoothMode mode) async {
    if (mode == _bluetoothMode) return;
    
    debugPrint('[ConnectionProvider] Changing Bluetooth mode from $_bluetoothMode to $mode');
    
    final wasAdvertising = _isAdvertising;
    
    // Stop current advertising if active
    if (wasAdvertising) {
      await stopAdvertising();
    }
    
    _bluetoothMode = mode;
    final modeString = mode == BluetoothMode.ble ? 'ble' : 'classic';
    
    // Persist the setting
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_bluetoothModeKey, modeString);
    } catch (e) {
      debugPrint('[ConnectionProvider] Error persisting Bluetooth mode: $e');
    }
    
    await _service.setMode(modeString);
    notifyListeners();
    
    // Restart advertising with new mode if it was previously active
    if (wasAdvertising) {
      await startAdvertising();
    }
  }

  Future<void> requestDiscoverable() async {
    // Ensure HID service is registered BEFORE making discoverable
    // This gives the Bluetooth stack a chance to update the Class of Device
    if (!_isAdvertising) {
      debugPrint('[ConnectionProvider] HID not registered, initializing before discoverable...');
      await _service.initialize(mode: _bluetoothMode == BluetoothMode.ble ? 'ble' : 'classic');
      // Wait a moment for the Bluetooth stack to register the HID profile
      // This delay allows the CoD to potentially update before advertising
      await Future.delayed(const Duration(milliseconds: 500));
    }
    await _service.requestDiscoverable();
  }

  Future<void> refreshPairedDevices() async {
    debugPrint('[ConnectionProvider] Refreshing paired devices...');
    _pairedDevices = await _service.getPairedDevices();
    debugPrint('[ConnectionProvider] Found ${_pairedDevices.length} paired devices');
    notifyListeners();
  }

  Future<void> startAdvertising() async {
    debugPrint('[ConnectionProvider] startAdvertising called with mode: $_bluetoothMode');
    await _service.initialize(mode: _bluetoothMode == BluetoothMode.ble ? 'ble' : 'classic');
    debugPrint('[ConnectionProvider] Service initialize() completed');
  }

  Future<void> stopAdvertising() async {
    debugPrint('[ConnectionProvider] stopAdvertising called');
    await _service.stop();
    debugPrint('[ConnectionProvider] Service stop() completed');
  }

  Future<void> connect(String address) async {
    debugPrint('[ConnectionProvider] connect called for address: $address');
    await _service.connect(address);
    debugPrint('[ConnectionProvider] Service connect() completed for: $address');
  }

  Future<void> disconnect(String address) async {
    debugPrint('[ConnectionProvider] disconnect called for address: $address');
    await _service.disconnect(address);
    debugPrint('[ConnectionProvider] Service disconnect() completed for: $address');
  }
}
