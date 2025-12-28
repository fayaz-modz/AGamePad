import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gamepad_descriptor.dart';

enum UDPConnectionState {
  disconnected,
  discovering,
  connecting,
  connected,
  error,
}

class UDPDeviceInfo {
  final String ip;
  final String deviceName;
  final int timestamp;

  UDPDeviceInfo({
    required this.ip,
    required this.deviceName,
    required this.timestamp,
  });

  factory UDPDeviceInfo.fromJson(Map<String, dynamic> json) {
    return UDPDeviceInfo(
      ip: json['ip'] as String,
      deviceName: json['device_name'] as String,
      timestamp: json['timestamp'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'ip': ip, 'device_name': deviceName, 'timestamp': timestamp};
  }

  @override
  String toString() {
    return '$deviceName ($ip)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UDPDeviceInfo && other.ip == ip;
  }

  @override
  int get hashCode => ip.hashCode;
}

class UDPGamepadService {
  static const int _broadcastPort = 2242;
  static const int _udpServerPort = 2243;
  static const String _deviceDiscoveryMessage = 'discover';
  static const String _descriptorMagic = 'DESC';
  static const String _descriptorAck = 'DESC_OK';
  static const int _connectionPollIntervalMs = 2000;
  static const String _lastConnectedIPKey = 'last_udp_connected_ip';

  // Singleton
  static final UDPGamepadService _instance = UDPGamepadService._internal();
  factory UDPGamepadService() => _instance;
  UDPGamepadService._internal() {
    if (kDebugMode) {
      debugPrint('[UDPGamepadService] Initializing service...');
    }
  }

  UDPConnectionState _connectionState = UDPConnectionState.disconnected;
  UDPDeviceInfo? _connectedDevice;
  RawDatagramSocket? _sender;
  RawDatagramSocket? _receiver;
  Timer? _connectionPollTimer;
  Timer? _discoveryTimer;
  bool _isInitialized = false;
  final Set<UDPDeviceInfo> _discoveredDevices = {};

  // Stream controllers
  final _connectionStateController =
      StreamController<UDPConnectionState>.broadcast();
  Stream<UDPConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  final _discoveredDevicesController =
      StreamController<List<UDPDeviceInfo>>.broadcast();
  Stream<List<UDPDeviceInfo>> get discoveredDevicesStream =>
      _discoveredDevicesController.stream;

  final _connectionStatusController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  // Getters
  UDPConnectionState get connectionState => _connectionState;
  UDPDeviceInfo? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectionState == UDPConnectionState.connected;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Create RECEIVER socket for listening to broadcasts (on port 2242)
      try {
        _receiver = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          _broadcastPort,
        );
        if (kDebugMode) {
          debugPrint(
            '[UDPGamepadService] Receiver bound to ${_receiver?.address.address}:${_receiver?.port}',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '[UDPGamepadService] Failed to bind receiver to port $_broadcastPort: $e',
          );
        }
        throw e;
      }

      // Create SENDER socket for sending data (on ephemeral port)
      try {
        _sender = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
        ); // Port 0 = ephemeral
        if (kDebugMode) {
          debugPrint(
            '[UDPGamepadService] Sender bound to ${_sender?.address.address}:${_sender?.port}',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[UDPGamepadService] Failed to create sender socket: $e');
        }
        throw e;
      }

      // Enable broadcast for sender
      try {
        _sender!.broadcastEnabled = true;
      } catch (e) {
        if (kDebugMode)
          debugPrint(
            '[UDPGamepadService] Warning: Broadcast enable failed: $e',
          );
      }

      // Setup single persistent listener for broadcasts on receiver socket
      _setupSocketListener();

      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('[UDPGamepadService] ✅ Initialized successfully');
        debugPrint(
          '[UDPGamepadService]    Receiver: ${_receiver?.address.address}:${_receiver?.port}',
        );
        debugPrint(
          '[UDPGamepadService]    Sender: ${_sender?.address.address}:${_sender?.port}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[UDPGamepadService] Initialization failed: $e');
      }
      _updateConnectionState(UDPConnectionState.error);
      // We do not rethrow, to avoid crashing the whole app.
      // The service will just be non-functional but safe.
    }
  }

  Future<void> dispose() async {
    await stopConnection();
    _discoveryTimer?.cancel();
    _connectionPollTimer?.cancel();
    _sender?.close();
    _receiver?.close();
    _connectionStateController.close();
    _discoveredDevicesController.close();
    _connectionStatusController.close();
    _isInitialized = false;
  }

  void _setupSocketListener() {
    if (_receiver == null) return;

    // Single persistent listener for all incoming broadcasts
    _receiver!.listen(
      (RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _receiver!.receive();
          if (datagram != null) {
            try {
              final response = utf8.decode(datagram.data);
              // Only log broadcasts if we are not connected, to avoid spam
              if (kDebugMode && !isConnected) {
                debugPrint(
                  '[UDPGamepadService] Received broadcast from ${datagram.address}: $response',
                );
              }

              final jsonData = jsonDecode(response) as Map<String, dynamic>;
              final device = UDPDeviceInfo.fromJson(jsonData);
              _discoveredDevices.add(device);
              _discoveredDevicesController.add(_discoveredDevices.toList());
            } catch (e) {
              if (kDebugMode) {
                debugPrint('[UDPGamepadService] Error parsing broadcast: $e');
              }
            }
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint('[UDPGamepadService] Socket error: $error');
        }
      },
    );
  }

  Future<List<UDPDeviceInfo>> discoverDevices({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!_isInitialized) await initialize();

    _updateConnectionState(UDPConnectionState.discovering);

    // If initialization failed, return empty list immediately
    if (_sender == null || _receiver == null) {
      if (kDebugMode) {
        debugPrint(
          '[UDPGamepadService] Cannot discover: service not initialized',
        );
      }
      _updateConnectionState(UDPConnectionState.error);
      return [];
    }

    try {
      if (kDebugMode) {
        debugPrint(
          '[UDPGamepadService] Listening for server broadcasts on port ${_sender?.port}...',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[UDPGamepadService] Warning: Sender socket error reading port: $e',
        );
      }
    }

    // Clear previous discoveries and wait for timeout
    _discoveredDevices.clear();
    await Future.delayed(timeout);

    if (_discoveredDevices.isEmpty) {
      _updateConnectionState(UDPConnectionState.disconnected);
    }

    return _discoveredDevices.toList();
  }

  Future<bool> connectToDevice(UDPDeviceInfo device) async {
    if (!_isInitialized) await initialize();

    try {
      _updateConnectionState(UDPConnectionState.connecting);

      // Create new UDP socket for data
      final dataSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );

      // Send HID descriptor first
      final descriptorBytes = utf8.encode(_descriptorMagic);
      final descriptorPacket = List<int>.filled(
        descriptorBytes.length + GamepadDescriptor.udpReportDescriptor.length,
        0,
      );
      for (int i = 0; i < descriptorBytes.length; i++) {
        descriptorPacket[i] = descriptorBytes[i];
      }
      for (int i = 0; i < GamepadDescriptor.udpReportDescriptor.length; i++) {
        descriptorPacket[descriptorBytes.length + i] =
            GamepadDescriptor.udpReportDescriptor[i];
      }

      // Setup persistent listener for both ACK and data drain immediately
      final ackCompleter = Completer<bool>();

      // We do not cancel this subscription explicitly unless we fail.
      // If we succeed, it stays alive to keep the socket active in the event loop.
      StreamSubscription? subscription;
      subscription = dataSocket.listen(
        (RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            final datagram = dataSocket.receive();
            if (datagram != null) {
              // Check for ACK if not yet completed
              if (!ackCompleter.isCompleted) {
                try {
                  final response = utf8.decode(datagram.data);
                  if (response == _descriptorAck) {
                    if (kDebugMode) {
                      debugPrint(
                        '[UDPGamepadService] Descriptor acknowledgment received',
                      );
                    }
                    ackCompleter.complete(true);
                    return;
                  }
                } catch (e) {
                  // ignore
                }
              }
              // Continued draining happens here automatically for subsequent packets
            }
          }
        },
        onError: (error) {
          if (kDebugMode) {
            debugPrint(
              '[UDPGamepadService] Acknowledgment/Socket error: $error',
            );
          }
          if (!ackCompleter.isCompleted) ackCompleter.complete(false);
        },
      );

      dataSocket.send(
        descriptorPacket,
        InternetAddress(device.ip),
        _udpServerPort,
      );

      final ackReceived = await ackCompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );

      if (!ackReceived) {
        subscription.cancel(); // Cancel only on failure
        dataSocket.close();
        _updateConnectionState(UDPConnectionState.error);
        return false;
      }

      // Close old connection and set new one
      _sender?.close();
      _sender = dataSocket;
      _connectedDevice = device;

      // Save last connected IP
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastConnectedIPKey, device.ip);

      _updateConnectionState(UDPConnectionState.connected);
      _startConnectionPolling();

      if (kDebugMode) {
        debugPrint('[UDPGamepadService] Connected to device: $device');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[UDPGamepadService] Connection failed: $e');
      }
      _updateConnectionState(UDPConnectionState.error);
      return false;
    }
  }

  Future<void> stopConnection() async {
    _connectionPollTimer?.cancel();
    _connectionPollTimer = null;

    if (_connectedDevice != null) {
      // Save last connected IP before disconnecting
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastConnectedIPKey, _connectedDevice!.ip);
    }

    _connectedDevice = null;
    _updateConnectionState(UDPConnectionState.disconnected);
    _connectionStatusController.add(false);

    if (kDebugMode) {
      debugPrint('[UDPGamepadService] Connection stopped');
    }
  }

  Uint8List? _lastInputReport;

  void sendInput({
    required int buttons,
    required int lx,
    required int ly,
    required int rx,
    required int ry,
    required int dpad,
  }) {
    if (!isConnected || _sender == null || _connectedDevice == null) {
      if (kDebugMode) {
        debugPrint('[UDPGamepadService] ❌ Cannot send input: not connected');
        debugPrint(
          '[UDPGamepadService]    Connection state: $_connectionState',
        );
        debugPrint(
          '[UDPGamepadService]    Sender: ${_sender != null ? "available" : "null"}',
        );
        debugPrint(
          '[UDPGamepadService]    Connected device: ${_connectedDevice?.deviceName ?? "null"}',
        );
      }
      return;
    }

    try {
      // Create report (10 bytes for UDP: ID + 6 Axes + 2 Buttons + 1 Hat)
      // Matches OS expectations (DS4 style) for 6-axis HID:
      // Index 1 (0x30): LX
      // Index 2 (0x31): LY
      // Index 3 (0x32): RX
      // Index 4 (0x33): L2
      // Index 5 (0x34): R2
      // Index 6 (0x35): RY
      final report = Uint8List(10);
      report[0] = 0x01; // Report ID 1
      report[1] = lx; // LX (Left X)
      report[2] = ly; // LY (Left Y)
      report[3] = rx; // RX (Right X) -> Usage 0x32 (Z)

      // L2 Trigger - Digital fallback to full axis -> Usage 0x33 (Rx)
      report[4] = (buttons & 0x100) != 0 ? 255 : 0;

      // R2 Trigger - Digital fallback to full axis -> Usage 0x34 (Ry)
      report[5] = (buttons & 0x200) != 0 ? 255 : 0;

      report[6] = ry; // RY (Right Y) -> Usage 0x35 (Rz)

      report[7] = buttons & 0xFF;
      report[8] = (buttons >> 8) & 0xFF;
      report[9] = dpad;

      // Store the last report for keep-alive pings
      _lastInputReport = report;

      _sender!.send(
        report,
        InternetAddress(_connectedDevice!.ip),
        _udpServerPort,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[UDPGamepadService] ❌ Failed to send input: $e');
      }
    }
  }

  void _startConnectionPolling() {
    _connectionPollTimer?.cancel();
    _connectionPollTimer = Timer.periodic(
      const Duration(milliseconds: _connectionPollIntervalMs),
      (_) => _pollConnectionStatus(),
    );
  }

  Future<void> _pollConnectionStatus() async {
    if (_connectedDevice == null || _sender == null) {
      _connectionStatusController.add(false);
      return;
    }

    try {
      // Use the last input report if available, otherwise send a neutral state
      // [ID, LX, LY, RX, L2, R2, RY, ButtonsL, ButtonsH, Hat]
      final packetToSend =
          _lastInputReport ??
          Uint8List.fromList([0x01, 127, 127, 127, 0, 0, 127, 0, 0, 8]);

      _sender!.send(
        packetToSend,
        InternetAddress(_connectedDevice!.ip),
        _udpServerPort,
      );

      // If we reach here without error, consider connection alive
      _connectionStatusController.add(true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[UDPGamepadService] Connection polling failed: $e');
      }
      _connectionStatusController.add(false);

      // If multiple polls fail, consider connection lost
      // This could be enhanced with retry logic
    }
  }

  void _updateConnectionState(UDPConnectionState newState) {
    if (_connectionState != newState) {
      _connectionState = newState;
      _connectionStateController.add(newState);
      if (kDebugMode) {
        debugPrint(
          '[UDPGamepadService] Connection state changed to: $newState',
        );
      }
    }
  }

  Future<String?> getLastConnectedIP() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastConnectedIPKey);
  }

  Future<UDPDeviceInfo?> getLastConnectedDevice() async {
    final ip = await getLastConnectedIP();
    if (ip == null) return null;

    // Try to rediscover the last device
    final devices = await discoverDevices(timeout: const Duration(seconds: 3));
    try {
      return devices.firstWhere((device) => device.ip == ip);
    } catch (e) {
      return null;
    }
  }
}
