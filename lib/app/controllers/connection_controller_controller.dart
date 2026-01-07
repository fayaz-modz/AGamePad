import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/services/bluetooth_gamepad_service.dart';
import '../data/services/udp_gamepad_service.dart';

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

// Extension to check if connection mode is Bluetooth
extension ConnectionModeExtension on ConnectionMode {
  bool get isBluetooth =>
      this == ConnectionMode.bluetoothClassic ||
      this == ConnectionMode.bluetoothBLE;
  bool get isUDP => this == ConnectionMode.udp;
}

class ConnectionController extends GetxController {
  final BluetoothGamepadService _bluetoothService = BluetoothGamepadService();
  final UDPGamepadService _udpService = UDPGamepadService();

  final _connectionMode = ConnectionMode.bluetoothClassic.obs;
  ConnectionMode get connectionMode => _connectionMode.value;

  final _isAdvertising = false.obs;
  bool get isAdvertising => _isAdvertising.value;

  final _isConnected = false.obs;
  bool get isConnected => _isConnected.value;

  final _connectedDeviceAddress = Rx<String?>(null);
  String? get connectedDeviceAddress => _connectedDeviceAddress.value;

  final _deviceName = "Unknown".obs;
  String get deviceName => _deviceName.value;

  final _pairedDevices = <Map<String, String>>[].obs;
  List<Map<String, String>> get pairedDevices => _pairedDevices;

  final _discoveredUDPDevices = <UDPDeviceInfo>[].obs;
  List<UDPDeviceInfo> get discoveredUDPDevices => _discoveredUDPDevices;

  final _connectedUDPDevice = Rx<UDPDeviceInfo?>(null);
  UDPDeviceInfo? get connectedUDPDevice => _connectedUDPDevice.value;

  final _udpConnectionState = UDPConnectionState.disconnected.obs;
  UDPConnectionState get udpConnectionState => _udpConnectionState.value;

  // Bluetooth mode: classic or ble (legacy)
  final _bluetoothMode = BluetoothMode.classic.obs;
  BluetoothMode get bluetoothMode => _bluetoothMode.value;

  @override
  void onInit() {
    super.onInit();
    debugPrint('[ConnectionController] Initializing ConnectionController...');
    _setupListeners();
    _loadSettings();
    _initializeCurrentMode();
  }

  void _setupListeners() {
    // Bluetooth listeners
    _bluetoothService.appStatusStream.listen((registered) {
      debugPrint(
        '[ConnectionController] Bluetooth app status changed: registered=$registered',
      );
      if (_connectionMode.value.isBluetooth) {
        _isAdvertising.value = registered;
      }
    });

    _bluetoothService.connectionStateStream.listen((event) {
      final state = event['state'];
      final address = event['address'];
      debugPrint(
        '[ConnectionController] Bluetooth connection state changed: state=$state, address=$address',
      );
      if (_connectionMode.value.isBluetooth) {
        // state 2 is Connected, 0 is Disconnected, 1 is Connecting, 3 is Disconnecting
        if (state == 2) {
          debugPrint(
            '[ConnectionController] Bluetooth device connected: $address',
          );
          _isConnected.value = true;
          _connectedDeviceAddress.value = address;
        } else if (state == 0) {
          debugPrint(
            '[ConnectionController] Bluetooth device disconnected: $address',
          );
          _isConnected.value = false;
          _connectedDeviceAddress.value = null;
        }
      }
    });

    // UDP listeners
    _udpService.connectionStateStream.listen((state) {
      debugPrint('[ConnectionController] UDP connection state changed: $state');
      if (_connectionMode.value == ConnectionMode.udp) {
        _udpConnectionState.value = state;
        _isConnected.value = state == UDPConnectionState.connected;
        _connectedUDPDevice.value = _udpService.connectedDevice;
        _isAdvertising.value =
            state == UDPConnectionState.connected ||
            state == UDPConnectionState.connecting;
      }
    });

    _udpService.discoveredDevicesStream.listen((devices) {
      debugPrint(
        '[ConnectionController] UDP devices discovered: ${devices.length}',
      );
      if (_connectionMode.value == ConnectionMode.udp) {
        _discoveredUDPDevices.value = devices;
      }
    });

    _udpService.connectionStatusStream.listen((isConnected) {
      debugPrint('[ConnectionController] UDP connection status: $isConnected');
      if (_connectionMode.value == ConnectionMode.udp) {
        _isConnected.value = isConnected;
      }
    });
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeString = prefs.getString('connection_mode');
      _connectionMode.value =
          _parseConnectionMode(modeString) ?? ConnectionMode.bluetoothClassic;
      final bluetoothModeString = prefs.getString('bluetooth_mode');
      _bluetoothMode.value = bluetoothModeString == 'ble'
          ? BluetoothMode.ble
          : BluetoothMode.classic;

      debugPrint(
        '[ConnectionController] Loaded connection mode: ${_connectionMode.value}',
      );
      debugPrint(
        '[ConnectionController] Loaded Bluetooth mode: ${_bluetoothMode.value}',
      );
    } catch (e) {
      debugPrint('[ConnectionController] Error loading settings: $e');
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
    switch (_connectionMode.value) {
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
  }

  Future<void> setConnectionMode(ConnectionMode mode) async {
    if (mode == _connectionMode.value) return;

    debugPrint(
      '[ConnectionController] Changing connection mode from ${_connectionMode.value} to $mode',
    );

    // Stop current mode
    await _stopCurrentMode();

    _connectionMode.value = mode;

    // Persist setting
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('connection_mode', _connectionModeToString(mode));
    } catch (e) {
      debugPrint('[ConnectionController] Error persisting connection mode: $e');
    }

    // Initialize new mode
    await _initializeCurrentMode();
  }

  Future<void> _stopCurrentMode() async {
    switch (_connectionMode.value) {
      case ConnectionMode.bluetoothClassic:
      case ConnectionMode.bluetoothBLE:
        await _bluetoothService.stop();
        break;
      case ConnectionMode.udp:
        await _udpService.stopConnection();
        break;
    }

    _isConnected.value = false;
    _connectedDeviceAddress.value = null;
    _connectedUDPDevice.value = null;
    _isAdvertising.value = false;
  }

  Future<void> _loadDeviceName() async {
    _deviceName.value = await _bluetoothService.getBluetoothName();
  }

  Future<void> setDeviceName(String name) async {
    switch (_connectionMode.value) {
      case ConnectionMode.bluetoothClassic:
      case ConnectionMode.bluetoothBLE:
        final success = await _bluetoothService.setBluetoothName(name);
        if (success) {
          _deviceName.value = name;
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
    if (_connectionMode.value.isBluetooth) {
      // Ensure HID service is registered BEFORE making discoverable
      if (!_isAdvertising.value) {
        debugPrint(
          '[ConnectionController] HID not registered, initializing before discoverable...',
        );
        final modeStr = _connectionMode.value == ConnectionMode.bluetoothBLE
            ? 'ble'
            : 'classic';
        await _bluetoothService.initialize(mode: modeStr);
        await Future.delayed(const Duration(milliseconds: 500));
      }
      await _bluetoothService.requestDiscoverable();
    }
  }

  Future<void> refreshDevices() async {
    switch (_connectionMode.value) {
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
    debugPrint('[ConnectionController] Refreshing paired devices...');
    _pairedDevices.value = await _bluetoothService.getPairedDevices();
    debugPrint(
      '[ConnectionController] Found ${_pairedDevices.length} paired devices',
    );
  }

  Future<void> discoverUDPDevices() async {
    debugPrint('[ConnectionController] Discovering UDP devices...');
    await _udpService.discoverDevices();
  }

  Future<void> startAdvertising() async {
    switch (_connectionMode.value) {
      case ConnectionMode.bluetoothClassic:
      case ConnectionMode.bluetoothBLE:
        debugPrint('[ConnectionController] Starting Bluetooth advertising');
        final modeStr = _connectionMode.value == ConnectionMode.bluetoothBLE
            ? 'ble'
            : 'classic';
        await _bluetoothService.initialize(mode: modeStr);
        break;
      case ConnectionMode.udp:
        debugPrint('[ConnectionController] UDP mode doesn\'t use advertising');
        break;
    }
  }

  Future<void> stopAdvertising() async {
    switch (_connectionMode.value) {
      case ConnectionMode.bluetoothClassic:
      case ConnectionMode.bluetoothBLE:
        debugPrint('[ConnectionController] Stopping Bluetooth advertising');
        await _bluetoothService.stop();
        break;
      case ConnectionMode.udp:
        debugPrint('[ConnectionController] Stopping UDP connection');
        await _udpService.stopConnection();
        break;
    }
  }

  Future<void> connectToDevice(dynamic device) async {
    switch (_connectionMode.value) {
      case ConnectionMode.bluetoothClassic:
      case ConnectionMode.bluetoothBLE:
        if (device is Map && device['address'] != null) {
          final address = device['address'] as String;
          debugPrint(
            '[ConnectionController] Connecting to Bluetooth device: $address',
          );
          await _bluetoothService.connect(address);
        }
        break;
      case ConnectionMode.udp:
        if (device is UDPDeviceInfo) {
          debugPrint(
            '[ConnectionController] Connecting to UDP device: $device',
          );
          await _udpService.connectToDevice(device);
        }
        break;
    }
  }

  Future<void> disconnectFromDevice(dynamic device) async {
    switch (_connectionMode.value) {
      case ConnectionMode.bluetoothClassic:
      case ConnectionMode.bluetoothBLE:
        if (device is Map && device['address'] != null) {
          final address = device['address'] as String;
          debugPrint(
            '[ConnectionController] Disconnecting Bluetooth device: $address',
          );
          await _bluetoothService.disconnect(address);
        }
        break;
      case ConnectionMode.udp:
        debugPrint('[ConnectionController] Disconnecting UDP device');
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
    int l2 = 0,
    int r2 = 0,
    required int dpad,
  }) {
    switch (_connectionMode.value) {
      case ConnectionMode.bluetoothClassic:
      case ConnectionMode.bluetoothBLE:
        _bluetoothService.sendInput(
          buttons: buttons,
          lx: lx,
          ly: ly,
          rx: rx,
          ry: ry,
          l2: l2,
          r2: r2,
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
          l2: l2,
          r2: r2,
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
    if (_connectionMode.value.isBluetooth) {
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
    if (_connectionMode.value.isBluetooth) {
      _bluetoothService.startKeepalive();
    }
  }

  void stopKeepalive() {
    if (_connectionMode.value.isBluetooth) {
      _bluetoothService.stopKeepalive();
    }
  }

  @override
  void onClose() {
    _stopCurrentMode();
    super.onClose();
  }
}
