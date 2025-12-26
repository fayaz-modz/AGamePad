import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/connection_provider.dart';

class ConnectionPage extends StatelessWidget {
  const ConnectionPage({super.key});

  Future<void> _handleAdvertisingToggle(BuildContext context, ConnectionProvider provider, bool value) async {
    debugPrint('[ConnectionPage] _handleAdvertisingToggle called with value: $value');
    
    if (!value) {
      debugPrint('[ConnectionPage] Stopping advertising...');
      await provider.stopAdvertising();
      debugPrint('[ConnectionPage] Advertising stopped');
      return;
    }
    
    debugPrint('[ConnectionPage] Attempting to start advertising...');

    // Check permissions
    debugPrint('[ConnectionPage] Checking Bluetooth permissions...');
    final statusConnect = await Permission.bluetoothConnect.status;
    final statusAdvertise = await Permission.bluetoothAdvertise.status;
    debugPrint('[ConnectionPage] bluetoothConnect: $statusConnect, bluetoothAdvertise: $statusAdvertise');

    if (statusConnect.isGranted && statusAdvertise.isGranted) {
      debugPrint('[ConnectionPage] Permissions granted, starting advertising...');
      await provider.startAdvertising();
      debugPrint('[ConnectionPage] Start advertising command sent');
      return;
    }
    
    debugPrint('[ConnectionPage] Permissions not granted, requesting...');

    if (!context.mounted) return;

    final bool? shouldRequest = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bluetooth Permission Required'),
        content: const Text(
          'To function as a gamepad, this app needs permission to access Bluetooth settings and advertise itself to other devices.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );

    if (shouldRequest == true) {
      debugPrint('[ConnectionPage] User chose to grant permissions, requesting...');
      final statuses = await [
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
      ].request();

      final connectGranted = statuses[Permission.bluetoothConnect] == PermissionStatus.granted;
      final advertiseGranted = statuses[Permission.bluetoothAdvertise] == PermissionStatus.granted;
      debugPrint('[ConnectionPage] Permission results - Connect: $connectGranted, Advertise: $advertiseGranted');

      if (connectGranted && advertiseGranted) {
        debugPrint('[ConnectionPage] All permissions granted, starting advertising...');
        await provider.startAdvertising();
        await provider.refreshPairedDevices();
        debugPrint('[ConnectionPage] Advertising started and devices refreshed');
      } else if (context.mounted) {
        debugPrint('[ConnectionPage] Permissions denied');
         if (statuses[Permission.bluetoothConnect] == PermissionStatus.permanentlyDenied || 
             statuses[Permission.bluetoothAdvertise] == PermissionStatus.permanentlyDenied) {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 content: const Text("Permissions are permanently denied. Please enable them in settings."),
                 action: SnackBarAction(
                   label: "Settings",
                   onPressed: openAppSettings,
                 ),
               )
             );
         } else {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("Bluetooth permissions are required to start."))
             );
         }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionProvider = Provider.of<ConnectionProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _handleRefresh(context, connectionProvider),
            tooltip: "Refresh Paired Devices",
          )
        ],
      ),
      body: ListView(
        children: [
          _buildStatusSection(context, connectionProvider),
          const Divider(),
          _buildAdvertisingSection(context, connectionProvider),
          const Divider(),
          _buildPairedDevicesSection(context, connectionProvider),
        ],
      ),
    );
  }

  Future<void> _handleRefresh(BuildContext context, ConnectionProvider provider) async {
    // Check permissions first
    final statusConnect = await Permission.bluetoothConnect.status;
    if (statusConnect.isGranted) {
      await provider.refreshPairedDevices();
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Refreshed paired devices"), duration: Duration(seconds: 1)));
      }
    } else {
      // Re-use logic or simple request
      final result = await Permission.bluetoothConnect.request();
      if (result.isGranted) {
         await provider.refreshPairedDevices();
      } else if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bluetooth Connect permission needed to list devices.")));
      }
    }
  }

  Widget _buildStatusSection(BuildContext context, ConnectionProvider provider) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (provider.isConnected) {
      statusColor = Colors.green;
      statusText = "Connected to ${provider.connectedDeviceAddress}";
      statusIcon = Icons.link;
    } else if (provider.isAdvertising) {
      statusColor = Colors.blue;
      statusText = "Broadcasting (Visible)";
      statusIcon = Icons.bluetooth_searching;
    } else {
      statusColor = Colors.grey;
      statusText = "Offline";
      statusIcon = Icons.bluetooth_disabled;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      color: statusColor.withValues(alpha: 0.1),
      child: Column(
        children: [
          Icon(statusIcon, size: 48, color: statusColor),
          const SizedBox(height: 16),
          Text(
            statusText,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: statusColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAdvertisingSection(BuildContext context, ConnectionProvider provider) {
    return SwitchListTile(
      title: const Text('Enable Gamepad'),
      subtitle: const Text('Turn on the gamepad controller and make it visible to other devices'),
      value: provider.isAdvertising,
      onChanged: (val) {
        debugPrint('[ConnectionPage] Enable Gamepad toggle pressed: $val');
        _handleAdvertisingToggle(context, provider, val);
      },
      secondary: const Icon(Icons.gamepad),
    );
  }

  Widget _buildPairedDevicesSection(BuildContext context, ConnectionProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text("Emulate Client (Connect to Host)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        if (provider.pairedDevices.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("No paired devices found. Pair a device in Android Bluetooth Settings first.", style: TextStyle(fontStyle: FontStyle.italic)),
          )
        else
          ...provider.pairedDevices.map((device) {
            final address = device['address'] ?? "";
            final name = device['name'] ?? "Unknown";
            final isConnectedToThis = provider.isConnected && provider.connectedDeviceAddress == address;

            return ListTile(
              leading: Icon(Icons.devices, color: isConnectedToThis ? Colors.green : null),
              title: Text(name),
              subtitle: Text(address),
              trailing: isConnectedToThis
                  ? TextButton(
                      onPressed: () {
                        debugPrint('[ConnectionPage] Disconnect button pressed for device: $name ($address)');
                        provider.disconnect(address);
                      },
                      child: const Text("Disconnect", style: TextStyle(color: Colors.red)),
                    )
                  : TextButton(
                      onPressed: () {
                        debugPrint('[ConnectionPage] Connect button pressed for device: $name ($address)');
                        provider.connect(address);
                      },
                      child: const Text("Connect"),
                    ),
            );
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextButton.icon(
              icon: const Icon(Icons.settings_bluetooth),
              label: const Text("Open Android Bluetooth Settings"),
              onPressed: () => openAppSettings(), // Best we can do usually, or specific intent if possible
            ),
          )
      ],
    );
  }
}
