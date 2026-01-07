import 'package:agamepad/app/controllers/connection_controller_controller.dart';
import 'package:agamepad/app/data/services/udp_gamepad_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';

class UDPControllerSection extends StatefulWidget {
  const UDPControllerSection({super.key});

  @override
  State<UDPControllerSection> createState() => _UDPControllerSectionState();
}

class _UDPControllerSectionState extends State<UDPControllerSection> {
  bool _isListening = false;
  final controller = Get.find<ConnectionController>();

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  void _startListening() {
    if (_isListening) return;

    if (mounted) {
      setState(() {
        _isListening = true;
      });
    } else {
      _isListening = true;
    }

    // Start discovery which will listen passively for broadcasts
    controller.discoverUDPDevices();
  }

  void _stopListening() {
    _isListening = false;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.wifi, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'UDP Controller',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: _isListening,
                      onChanged: (value) {
                        if (value) {
                          _startListening();
                        } else {
                          _stopListening();
                        }
                      },
                      activeTrackColor: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _buildConnectionStatus(controller),
                  ],
                ),
              ],
            ),
          ),

          if (_isListening &&
              controller.udpConnectionState == UDPConnectionState.discovering)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Listening for server broadcasts...',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

          if (controller.discoveredUDPDevices.isNotEmpty)
            _buildDiscoveredDevices(context, controller),

          if (controller.connectedUDPDevice != null)
            _buildConnectedDevice(context, controller),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Instructions:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('1. Start the UHID server on your target device'),
                const Text(
                  '2. Toggle the switch to start listening for broadcasts',
                ),
                const Text('3. Select a discovered server to connect'),
                const Text(
                  '4. The server will create a virtual gamepad device',
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildConnectionStatus(ConnectionController controller) {
    UDPConnectionState state = controller.udpConnectionState;
    Color color;
    String text;
    IconData icon;

    switch (state) {
      case UDPConnectionState.connected:
        color = Colors.green;
        text = 'Connected';
        icon = Icons.check_circle;
        break;
      case UDPConnectionState.connecting:
        color = Colors.orange;
        text = 'Connecting';
        icon = Icons.sync;
        break;
      case UDPConnectionState.discovering:
        color = Colors.blue;
        text = 'Listening';
        icon = Icons.hearing;
        break;
      case UDPConnectionState.error:
        color = Colors.red;
        text = 'Error';
        icon = Icons.error;
        break;
      default:
        color = Colors.grey;
        text = 'Disconnected';
        icon = Icons.wifi_off;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveredDevices(
    BuildContext context,
    ConnectionController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Available Servers:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        ...controller.discoveredUDPDevices.map((device) {
          final isConnected = controller.connectedUDPDevice?.ip == device.ip;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: Icon(
                Icons.dvr,
                color: isConnected ? Colors.green : Colors.blue,
              ),
              title: Text(device.deviceName),
              subtitle: Text(device.ip),
              trailing: isConnected
                  ? ElevatedButton(
                      onPressed: () => _disconnectDevice(context, controller),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Disconnect'),
                    )
                  : ElevatedButton(
                      onPressed: () =>
                          _connectToDevice(context, controller, device),
                      child: const Text('Connect'),
                    ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildConnectedDevice(
    BuildContext context,
    ConnectionController controller,
  ) {
    final device = controller.connectedUDPDevice!;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              const Text(
                'Connected to Server',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Device: ${device.deviceName}'),
          Text('IP: ${device.ip}'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _disconnectDevice(context, controller),
            icon: const Icon(Icons.link_off),
            label: const Text('Disconnect'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _connectToDevice(
    BuildContext context,
    ConnectionController controller,
    UDPDeviceInfo device,
  ) async {
    try {
      await controller.connectToDevice(device);

      Get.snackbar(
        'Connecting',
        'Connecting to ${device.deviceName}...',
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to connect: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _disconnectDevice(
    BuildContext context,
    ConnectionController controller,
  ) async {
    try {
      await controller.disconnectFromDevice(controller.connectedUDPDevice!);

      Get.snackbar(
        'Disconnected',
        'Disconnected from server',
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Disconnect failed: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
