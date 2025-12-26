import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/bluetooth_gamepad_service.dart';

class ConnectionProvider with ChangeNotifier {
  final BluetoothGamepadService _service = BluetoothGamepadService();
  
  bool _isAdvertising = false;
  bool get isAdvertising => _isAdvertising;

  bool _isConnected = false;
  bool get isConnected => _isConnected;
  
  String? _connectedDeviceAddress;
  String? get connectedDeviceAddress => _connectedDeviceAddress;

  List<Map<String, String>> _pairedDevices = [];
  List<Map<String, String>> get pairedDevices => _pairedDevices;

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
  }

  Future<void> refreshPairedDevices() async {
    debugPrint('[ConnectionProvider] Refreshing paired devices...');
    _pairedDevices = await _service.getPairedDevices();
    debugPrint('[ConnectionProvider] Found ${_pairedDevices.length} paired devices');
    notifyListeners();
  }

  Future<void> startAdvertising() async {
    debugPrint('[ConnectionProvider] startAdvertising called');
    await _service.initialize();
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
