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
          _buildBluetoothModeSection(context, connectionProvider),
          const Divider(),
          _buildDeviceInfoSection(context, connectionProvider),
          const Divider(),
          _buildAdvertisingSection(context, connectionProvider),
          const Divider(),
          _buildPairedDevicesSection(context, connectionProvider),
        ],
      ),
    );
  }

  Widget _buildBluetoothModeSection(BuildContext context, ConnectionProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text("Bluetooth Mode", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SegmentedButton<BluetoothMode>(
            segments: const [
              ButtonSegment(
                value: BluetoothMode.classic,
                label: Text('Classic'),
                icon: Icon(Icons.bluetooth),
              ),
              ButtonSegment(
                value: BluetoothMode.ble,
                label: Text('BLE'),
                icon: Icon(Icons.bluetooth_searching),
              ),
            ],
            selected: {provider.bluetoothMode},
            onSelectionChanged: (Set<BluetoothMode> selected) {
              provider.setBluetoothMode(selected.first);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: provider.bluetoothMode == BluetoothMode.ble 
                  ? Colors.blue.withValues(alpha: 0.1) 
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: provider.bluetoothMode == BluetoothMode.ble 
                    ? Colors.blue.withValues(alpha: 0.3) 
                    : Colors.grey.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  provider.bluetoothMode == BluetoothMode.ble 
                      ? Icons.info_outline 
                      : Icons.speed,
                  color: provider.bluetoothMode == BluetoothMode.ble 
                      ? Colors.blue 
                      : Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    provider.bluetoothMode == BluetoothMode.ble
                        ? 'BLE Mode: Shows as Gamepad during discovery.\nHigher latency (~15-30ms more). Best for Fire TV pairing.'
                        : 'Classic Mode: Lowest latency for gaming.\nMay show as Phone during discovery.',
                    style: TextStyle(
                      fontSize: 12,
                      color: provider.bluetoothMode == BluetoothMode.ble 
                          ? Colors.blue[700] 
                          : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceInfoSection(BuildContext context, ConnectionProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text("Device Identity", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        ListTile(
          title: const Text("Bluetooth Name"),
          subtitle: Text(provider.deviceName),
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showNameEditDialog(context, provider),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ElevatedButton.icon(
            onPressed: () => provider.requestDiscoverable(),
            icon: const Icon(Icons.visibility),
            label: const Text("Make Discoverable (for pairing)"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 45),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _showNameEditDialog(BuildContext context, ConnectionProvider provider) async {
    final controller = TextEditingController(text: provider.deviceName);
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Set Device Name"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "New Bluetooth Name",
            hintText: "e.g. Xbox Wireless Controller",
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.setBluetoothName(controller.text);
              }
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
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
    final isBleMode = provider.bluetoothMode == BluetoothMode.ble;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            isBleMode ? "Connection Info (BLE Mode)" : "Emulate Client (Connect to Host)", 
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ),
        
        // Show BLE mode explanation
        if (isBleMode)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'In BLE mode, you are a peripheral.\n'
                      'The HOST device (Fire TV, PC, etc.) must connect TO you.\n\n'
                      '1. Enable Gamepad above\n'
                      '2. On the host, scan for Bluetooth devices\n'
                      '3. Select your phone and confirm pairing',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // Show paired devices only in Classic mode
        if (!isBleMode) ...[
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
        ],
        
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextButton.icon(
            icon: const Icon(Icons.settings_bluetooth),
            label: const Text("Open Android Bluetooth Settings"),
            onPressed: () => openAppSettings(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
