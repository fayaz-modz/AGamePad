import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/bluetooth_gamepad_service.dart';
import '../services/udp_gamepad_service.dart';

/// Connection mode options
enum ConnectionMode {
  /// Classic Bluetooth HID - Lower latency, shows as phone during discovery
  bluetoothClassic,

  /// BLE HID - Higher latency (~15-30ms more), shows as gamepad during discovery
  bluetoothBLE,

  /// UDP over WiFi - For UHID server
  udp,
}

/// Bluetooth mode options (legacy compatibility)
enum BluetoothMode {
  /// Classic Bluetooth HID
  classic,

  /// BLE HID
  ble,
}

class ConnectionProvider with ChangeNotifier {
  final BluetoothGamepadService _bluetoothService = BluetoothGamepadService();
  final UDPGamepadService _udpService = UDPGamepadService();

  ConnectionMode _connectionMode = ConnectionMode.bluetoothClassic;
  ConnectionMode get connectionMode => _connectionMode;

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

  List<UDPDeviceInfo> _discoveredUDPDevices = [];
  List<UDPDeviceInfo> get discoveredUDPDevices => _discoveredUDPDevices;

  UDPDeviceInfo? _connectedUDPDevice;
  UDPDeviceInfo? get connectedUDPDevice => _connectedUDPDevice;

  UDPConnectionState _udpConnectionState = UDPConnectionState.disconnected;
  UDPConnectionState get udpConnectionState => _udpConnectionState;

  // Bluetooth mode: classic or ble (legacy)
  BluetoothMode _bluetoothMode = BluetoothMode.classic;
  BluetoothMode get bluetoothMode => _bluetoothMode;

  ConnectionProvider() {
    debugPrint('[ConnectionProvider] Initializing ConnectionProvider...');
    _setupListeners();
    _loadSettings();
    _initializeCurrentMode();
  }

  void _setupListeners() {
    // Bluetooth listeners
    _bluetoothService.appStatusStream.listen((registered) {
      debugPrint(
        '[ConnectionProvider] Bluetooth app status changed: registered=$registered',
      );
      if (_connectionMode.isBluetooth) {
        _isAdvertising = registered;
        notifyListeners();
      }
    });

    _bluetoothService.connectionStateStream.listen((event) {
      final state = event['state'];
      final address = event['address'];
      debugPrint(
        '[ConnectionProvider] Bluetooth connection state changed: state=$state, address=$address',
      );
      if (_connectionMode.isBluetooth) {
        // state 2 is Connected, 0 is Disconnected, 1 is Connecting, 3 is Disconnecting
        if (state == 2) {
          debugPrint(
            '[ConnectionProvider] Bluetooth device connected: $address',
          );
          _isConnected = true;
          _connectedDeviceAddress = address;
        } else if (state == 0) {
          debugPrint(
            '[ConnectionProvider] Bluetooth device disconnected: $address',
          );
          _isConnected = false;
          _connectedDeviceAddress = null;
        }
        notifyListeners();
      }
    });

    // UDP listeners
    _udpService.connectionStateStream.listen((state) {
      debugPrint('[ConnectionProvider] UDP connection state changed: $state');
      if (_connectionMode == ConnectionMode.udp) {
        _udpConnectionState = state;
        _isConnected = state == UDPConnectionState.connected;
        _connectedUDPDevice = _udpService.connectedDevice;
        _isAdvertising =
            state == UDPConnectionState.connected ||
            state == UDPConnectionState.connecting;
        notifyListeners();
      }
    });

    _udpService.discoveredDevicesStream.listen((devices) {
      debugPrint(
        '[ConnectionProvider] UDP devices discovered: ${devices.length}',
      );
      if (_connectionMode == ConnectionMode.udp) {
        _discoveredUDPDevices = devices;
        notifyListeners();
      }
    });

    _udpService.connectionStatusStream.listen((isConnected) {
      debugPrint('[ConnectionProvider] UDP connection status: $isConnected');
      if (_connectionMode == ConnectionMode.udp) {
        _isConnected = isConnected;
        notifyListeners();
      }
    });
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeString = prefs.getString('connection_mode');
      _connectionMode =
          _parseConnectionMode(modeString) ?? ConnectionMode.bluetoothClassic;
      final bluetoothModeString = prefs.getString('bluetooth_mode');
      _bluetoothMode = bluetoothModeString == 'ble'
          ? BluetoothMode.ble
          : BluetoothMode.classic;

      debugPrint(
        '[ConnectionProvider] Loaded connection mode: $_connectionMode',
      );
      debugPrint('[ConnectionProvider] Loaded Bluetooth mode: $_bluetoothMode');
    } catch (e) {
      debugPrint('[ConnectionProvider] Error loading settings: $e');
    }
  }

  ConnectionMode? _parseConnectionMode(String? modeString) {
    switch (modeString) {
      case 'bluetooth_classic':
        return ConnectionMode.bluetoothClassic;
      case 'bluetooth_ble':
        return ConnectionMode.bluetoothBLE;
      case 'udp':
        return ConnectionMode.udp;
      default:
        return null;
    }
  }

  String _connectionModeToString(ConnectionMode mode) {
    switch (mode) {
      case ConnectionMode.bluetoothClassic:
        return 'bluetooth_classic';
      case ConnectionMode.bluetoothBLE:
        return 'bluetooth_ble';
      case ConnectionMode.udp:
        return 'udp';
    }
  }

  Future<void> _initializeCurrentMode() async {
    switch (_connectionMode) {
      case ConnectionMode.bluetoothClassic:
        await _loadDeviceName();
        // Ensure service knows we want classic
        await _bluetoothService.setMode('classic');
        break;
      case ConnectionMode.bluetoothBLE:
        await _loadDeviceName();
        // Ensure service knows we want BLE
        await _bluetoothService.setMode('ble');
        break;
      case ConnectionMode.udp:
        await _udpService.initialize();
        break;
    }

    refreshDevices();
    notifyListeners();
  }

  Future<void> setConnectionMode(ConnectionMode mode) async {
    if (mode == _connectionMode) return;

    debugPrint(
      '[ConnectionProvider] Changing connection mode from $_connectionMode to $mode',
    );

    // Stop current mode
    await _stopCurrentMode();

    _connectionMode = mode;

    // Persist setting
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('connection_mode', _connectionModeToString(mode));
    } catch (e) {
      debugPrint('[ConnectionProvider] Error persisting connection mode: $e');
    }

    // Initialize new mode
    await _initializeCurrentMode();
  }

  Future<void> _stopCurrentMode() async {
    switch (_connectionMode) {
      case ConnectionMode.bluetoothClassic:
      case ConnectionMode.bluetoothBLE:
        await _bluetoothService.stop();
        break;
      case ConnectionMode.udp:
        await _udpService.stopConnection();
        break;
    }

    _isConnected = false;
    _connectedDeviceAddress = null;
    _connectedUDPDevice = null;
    _isAdvertising = false;
  }

  Future<void> _loadDeviceName() async {
    _deviceName = await _bluetoothService.getBluetoothName();
    notifyListeners();
  }

  Future<void> setDeviceName(String name) async {
    switch (_connectionMode) {
      case ConnectionMode.bluetoothClassic:
      case ConnectionMode.bluetoothBLE:
        final success = await _bluetoothService.setBluetoothName(name);
        if (success) {
          _deviceName = name;
          notifyListeners();
        }
        break;
      case ConnectionMode.udp:
        // UDP device name is handled on the server side
        break;
    }
  }

  /// Set the Bluetooth mode (classic or ble) - legacy method
  Future<void> setBluetoothMode(BluetoothMode mode) async {
    // Switch to corresponding Bluetooth connection mode
    final newConnectionMode = mode == BluetoothMode.ble
        ? ConnectionMode.bluetoothBLE
        : ConnectionMode.bluetoothClassic;
    await setConnectionMode(newConnectionMode);
  }

  Future<void> requestDiscoverable() async {
    if (_connectionMode.isBluetooth) {
      // Ensure HID service is registered BEFORE making discoverable
      if (!_isAdvertising) {
        debugPrint(
          '[ConnectionProvider] HID not registered, initializing before discoverable...',
        );
        final modeStr = _connectionMode == ConnectionMode.bluetoothBLE ? 'ble' : 'classic';
        await _bluetoothService.initialize(mode: modeStr);
        await Future.delayed(const Duration(milliseconds: 500));
      }
      await _bluetoothService.requestDiscoverable();
    }
  }

  Future<void> refreshDevices() async {
    switch (_connectionMode) {
      case ConnectionMode.bluetoothClassic:
      case ConnectionMode.bluetoothBLE:
        await refreshPairedDevices();
        break;
      case ConnectionMode.udp:
        await discoverUDPDevices();
        break;
    }
  }

  Future<void> refreshPairedDevices() async {
    debugPrint('[ConnectionProvider] Refreshing paired devices...');
    _pairedDevices = await _bluetoothService.getPairedDevices();
    debugPrint(
      '[ConnectionProvider] Found ${_pairedDevices.length} paired devices',
    );
    notifyListeners();
  }

  Future<void> discoverUDPDevices() async {
    debugPrint('[ConnectionProvider] Discovering UDP devices...');
    await _udpService.discoverDevices();
  }

  Future<void> startAdvertising() async {
    switch (_connectionMode) {
      case ConnectionMode.bluetoothClassic:
      case ConnectionMode.bluetoothBLE:
        debugPrint('[ConnectionProvider] Starting Bluetooth advertising');
        final modeStr = _connectionMode == ConnectionMode.bluetoothBLE ? 'ble' : 'classic';
        await _bluetoothService.initialize(mode: modeStr);
        break;
      case ConnectionMode.udp:
        debugPrint('[ConnectionProvider] UDP mode doesn\'t use advertising');
        break;
    }
  }

  Future<void> stopAdvertising() async {
    switch (_connectionMode) {
      case ConnectionMode.bluetoothClassic:
      case ConnectionMode.bluetoothBLE:
        debugPrint('[ConnectionProvider] Stopping Bluetooth advertising');
        await _bluetoothService.stop();
        break;
      case ConnectionMode.udp:
        debugPrint('[ConnectionProvider] Stopping UDP connection');
        await _udpService.stopConnection();
        break;
    }
  }

  Future<void> connectToDevice(dynamic device) async {
    switch (_connectionMode) {
      case ConnectionMode.bluetoothClassic:
      case ConnectionMode.bluetoothBLE:
        if (device is Map && device['address'] != null) {
          final address = device['address'] as String;
          debugPrint(
            '[ConnectionProvider] Connecting to Bluetooth device: $address',
          );
          await _bluetoothService.connect(address);
        }
        break;
      case ConnectionMode.udp:
        if (device is UDPDeviceInfo) {
          debugPrint('[ConnectionProvider] Connecting to UDP device: $device');
          await _udpService.connectToDevice(device);
        }
        break;
    }
  }

  Future<void> disconnectFromDevice(dynamic device) async {
    switch (_connectionMode) {
      case ConnectionMode.bluetoothClassic:
      case ConnectionMode.bluetoothBLE:
        if (device is Map && device['address'] != null) {
          final address = device['address'] as String;
          debugPrint(
            '[ConnectionProvider] Disconnecting Bluetooth device: $address',
          );
          await _bluetoothService.disconnect(address);
        }
        break;
      case ConnectionMode.udp:
        debugPrint('[ConnectionProvider] Disconnecting UDP device');
        await _udpService.stopConnection();
        break;
    }
  }

  // Method for sending gamepad input - delegates to appropriate service
  void sendGamepadInput({
    required int buttons,
    required int lx,
    required int ly,
    required int rx,
    required int ry,
    required int dpad,
  }) {
    switch (_connectionMode) {
      case ConnectionMode.bluetoothClassic:
      case ConnectionMode.bluetoothBLE:
        _bluetoothService.sendInput(
          buttons: buttons,
          lx: lx,
          ly: ly,
          rx: rx,
          ry: ry,
          dpad: dpad,
        );
        break;
      case ConnectionMode.udp:
        _udpService.sendInput(
          buttons: buttons,
          lx: lx,
          ly: ly,
          rx: rx,
          ry: ry,
          dpad: dpad,
        );
        break;
    }
  }

  // Method for sending mouse input - only supported over Bluetooth for now
  void sendMouseInput({
    required int dx,
    required int dy,
    required int buttons,
    int wheel = 0,
  }) {
    if (_connectionMode.isBluetooth) {
      _bluetoothService.sendMouseInput(
        dx: dx,
        dy: dy,
        buttons: buttons,
        wheel: wheel,
      );
    }
    // UDP doesn't support mouse HID directly yet in the current server spec
  }

  // Keepalive methods for Bluetooth
  void startKeepalive() {
    if (_connectionMode.isBluetooth) {
      _bluetoothService.startKeepalive();
    }
  }

  void stopKeepalive() {
    if (_connectionMode.isBluetooth) {
      _bluetoothService.stopKeepalive();
    }
  }

  @override
  void dispose() {
    _stopCurrentMode();
    super.dispose();
  }
}

// Extension to check if connection mode is Bluetooth
extension ConnectionModeExtension on ConnectionMode {
  bool get isBluetooth =>
      this == ConnectionMode.bluetoothClassic ||
      this == ConnectionMode.bluetoothBLE;
  bool get isUDP => this == ConnectionMode.udp;
}
