import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/connection_provider.dart';
import '../../services/udp_gamepad_service.dart';
import 'dart:async';

class UDPControllerSection extends StatefulWidget {
  const UDPControllerSection({super.key});

  @override
  State<UDPControllerSection> createState() => _UDPControllerSectionState();
}

class _UDPControllerSectionState extends State<UDPControllerSection> {
  bool _isListening = false;

  @override
  void dispose() {
    super.dispose();
    _stopListening();
  }

  void _startListening(ConnectionProvider provider) {
    if (_isListening) return;

    if (mounted) {
      setState(() {
        _isListening = true;
      });
    } else {
      _isListening = true;
    }

    // Start discovery which will listen passively for broadcasts
    provider.discoverUDPDevices();
  }

  void _stopListening() {
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    } else {
      _isListening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, provider, child) {
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
                            _startListening(provider);
                          } else {
                            _stopListening();
                          }
                        },
                        activeColor: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      _buildConnectionStatus(provider),
                    ],
                  ),
                ],
              ),
            ),

            if (_isListening && provider.udpConnectionState == UDPConnectionState.discovering)
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

            if (provider.discoveredUDPDevices.isNotEmpty)
              _buildDiscoveredDevices(context, provider),

            if (provider.connectedUDPDevice != null)
              _buildConnectedDevice(context, provider),

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
                  const Text('2. Toggle the switch to start listening for broadcasts'),
                  const Text('3. Select a discovered server to connect'),
                  const Text('4. The server will create a virtual gamepad device'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConnectionStatus(ConnectionProvider provider) {
    UDPConnectionState state = provider.udpConnectionState;
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
    ConnectionProvider provider,
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
        ...provider.discoveredUDPDevices.map((device) {
          final isConnected = provider.connectedUDPDevice?.ip == device.ip;

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
                      onPressed: () => _disconnectDevice(context, provider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Disconnect'),
                    )
                  : ElevatedButton(
                      onPressed: () =>
                          _connectToDevice(context, provider, device),
                      child: const Text('Connect'),
                    ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildConnectedDevice(
    BuildContext context,
    ConnectionProvider provider,
  ) {
    final device = provider.connectedUDPDevice!;

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
            onPressed: () => _disconnectDevice(context, provider),
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
    ConnectionProvider provider,
    UDPDeviceInfo device,
  ) async {
    try {
      await provider.connectToDevice(device);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connecting to ${device.deviceName}...'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _disconnectDevice(
    BuildContext context,
    ConnectionProvider provider,
  ) async {
    try {
      await provider.disconnectFromDevice(provider.connectedUDPDevice!);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Disconnected from server'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Disconnect failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
