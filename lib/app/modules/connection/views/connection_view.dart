import 'package:agamepad/app/controllers/connection_controller_controller.dart';
import 'package:agamepad/app/modules/connection/views/udp_controller_section.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class ConnectionView extends GetView<ConnectionController> {
  const ConnectionView({super.key});

  Future<void> _handleAdvertisingToggle(bool value) async {
    debugPrint(
      '[ConnectionPage] _handleAdvertisingToggle called with value: $value',
    );

    if (!value) {
      debugPrint('[ConnectionPage] Stopping advertising...');
      await controller.stopAdvertising();
      debugPrint('[ConnectionPage] Advertising stopped');
      return;
    }

    debugPrint('[ConnectionPage] Attempting to start advertising...');

    if (controller.connectionMode.isBluetooth) {
      // Check permissions for Bluetooth
      debugPrint('[ConnectionPage] Checking Bluetooth permissions...');
      final statusConnect = await Permission.bluetoothConnect.status;
      final statusAdvertise = await Permission.bluetoothAdvertise.status;
      debugPrint(
        '[ConnectionPage] bluetoothConnect: $statusConnect, bluetoothAdvertise: $statusAdvertise',
      );

      if (statusConnect.isGranted && statusAdvertise.isGranted) {
        debugPrint(
          '[ConnectionPage] Permissions granted, starting advertising...',
        );
        await controller.startAdvertising();
        debugPrint('[ConnectionPage] Start advertising command sent');
        return;
      }

      debugPrint('[ConnectionPage] Permissions not granted, requesting...');

      final bool? shouldRequest = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Bluetooth Permission Required'),
          content: const Text(
            'To function as a gamepad, this app needs permission to access Bluetooth settings and advertise itself to other devices.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Grant Permission'),
            ),
          ],
        ),
      );

      if (shouldRequest == true) {
        debugPrint(
          '[ConnectionPage] User chose to grant permissions, requesting...',
        );
        final statuses = await [
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
        ].request();

        final connectGranted =
            statuses[Permission.bluetoothConnect] == PermissionStatus.granted;
        final advertiseGranted =
            statuses[Permission.bluetoothAdvertise] == PermissionStatus.granted;
        debugPrint(
          '[ConnectionPage] Permission results - Connect: $connectGranted, Advertise: $advertiseGranted',
        );

        if (connectGranted && advertiseGranted) {
          debugPrint(
            '[ConnectionPage] All permissions granted, starting advertising...',
          );
          await controller.startAdvertising();
          await controller.refreshPairedDevices();
          debugPrint(
            '[ConnectionPage] Advertising started and devices refreshed',
          );
        } else {
          debugPrint('[ConnectionPage] Permissions denied');
          if (statuses[Permission.bluetoothConnect] ==
                  PermissionStatus.permanentlyDenied ||
              statuses[Permission.bluetoothAdvertise] ==
                  PermissionStatus.permanentlyDenied) {
            Get.snackbar(
              "Permissions denied",
              "Permissions are permanently denied. Please enable them in settings.",
              mainButton: TextButton(
                onPressed: openAppSettings,
                child: const Text("Settings"),
              ),
            );
          } else {
            Get.snackbar(
              "Permissions required",
              "Bluetooth permissions are required to start.",
            );
          }
        }
      }
    } else {
      // UDP mode - just start advertising
      await controller.startAdvertising();
      debugPrint('[ConnectionPage] UDP mode started');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _handleRefresh(),
            tooltip: "Refresh Devices",
          ),
        ],
      ),
      body: Obx(() {
        return ListView(
          children: [
            _buildStatusSection(),
            const Divider(),
            _buildConnectionModeSection(context),
            const Divider(),
            if (controller.connectionMode.isBluetooth) ...[
              _buildDeviceInfoSection(),
              const Divider(),
              _buildAdvertisingSection(),
              const Divider(),
              _buildPairedDevicesSection(),
            ] else ...[
              const UDPControllerSection(),
            ],
          ],
        );
      }),
    );
  }

  Widget _buildConnectionModeSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Connection Mode',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text('Bluetooth Classic'),
                  selected:
                      controller.connectionMode ==
                      ConnectionMode.bluetoothClassic,
                  onSelected: (_) => controller.setConnectionMode(
                    ConnectionMode.bluetoothClassic,
                  ),
                ),
                ChoiceChip(
                  label: Text('Bluetooth BLE'),
                  selected:
                      controller.connectionMode == ConnectionMode.bluetoothBLE,
                  onSelected: (_) =>
                      controller.setConnectionMode(ConnectionMode.bluetoothBLE),
                ),
                ChoiceChip(
                  label: Text('UDP (WiFi)'),
                  selected: controller.connectionMode == ConnectionMode.udp,
                  onSelected: (_) =>
                      controller.setConnectionMode(ConnectionMode.udp),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (controller.isConnected) {
      statusColor = Colors.green;
      if (controller.connectionMode.isBluetooth) {
        statusText = "Connected to ${controller.connectedDeviceAddress}";
      } else {
        statusText =
            "Connected to ${controller.connectedUDPDevice?.deviceName ?? 'Unknown'}";
      }
      statusIcon = Icons.link;
    } else if (controller.isAdvertising) {
      statusColor = Colors.blue;
      statusText = controller.connectionMode.isBluetooth
          ? "Broadcasting (Visible)"
          : "Server Active";
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            "Device Identity",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ),
        ListTile(
          title: const Text("Device Name"),
          subtitle: Text(controller.deviceName),
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showNameEditDialog(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ElevatedButton.icon(
            onPressed: () => controller.requestDiscoverable(),
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

  Future<void> _showNameEditDialog() async {
    final textController = TextEditingController(text: controller.deviceName);
    return Get.dialog(
      AlertDialog(
        title: const Text("Set Device Name"),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            labelText: "New Device Name",
            hintText: "e.g. Xbox Wireless Controller",
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              if (textController.text.isNotEmpty) {
                controller.setDeviceName(textController.text);
              }
              Get.back();
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRefresh() async {
    if (controller.connectionMode.isBluetooth) {
      // Check permissions first
      final statusConnect = await Permission.bluetoothConnect.status;
      if (statusConnect.isGranted) {
        await controller.refreshPairedDevices();
        Get.snackbar(
          "Refreshed",
          "Refreshed paired devices",
          duration: const Duration(seconds: 1),
        );
      } else {
        // Re-use logic or simple request
        final result = await Permission.bluetoothConnect.request();
        if (result.isGranted) {
          await controller.refreshPairedDevices();
        } else {
          Get.snackbar(
            "Permission denied",
            "Bluetooth Connect permission needed to list devices.",
          );
        }
      }
    } else {
      // UDP mode - just discover devices
      await controller.refreshDevices();
      if (controller.discoveredUDPDevices.isEmpty) {
        Get.snackbar(
          "No servers found",
          "Make sure server is running on same network.",
          duration: const Duration(seconds: 3),
        );
      } else {
        Get.snackbar(
          "Servers found",
          "Found ${controller.discoveredUDPDevices.length} server(s)",
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  Widget _buildAdvertisingSection() {
    return SwitchListTile(
      title: const Text('Enable Gamepad'),
      subtitle: const Text(
        'Turn on to make device discoverable and start gamepad functionality',
      ),
      value: controller.isAdvertising,
      onChanged: (val) {
        debugPrint('[ConnectionPage] Enable Gamepad toggle pressed: $val');
        _handleAdvertisingToggle(val);
      },
      secondary: const Icon(Icons.gamepad),
    );
  }

  Widget _buildPairedDevicesSection() {
    final isBleMode = controller.connectionMode == ConnectionMode.bluetoothBLE;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            isBleMode ? "Connection Info (BLE Mode)" : "Available Devices",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),

        // Show BLE mode explanation
        if (isBleMode)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your device will appear as gamepad device to other devices.\n'
                          'This improves compatibility with most devices that support BLE.',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        // Show paired devices only in Classic mode
        if (!isBleMode) ...[
          if (controller.pairedDevices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "No paired devices found. Pair a device in Android Bluetooth Settings first.",
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            )
          else
            ...controller.pairedDevices.map((device) {
              final address = device['address'] ?? "";
              final name = device['name'] ?? "Unknown";
              final isConnectedToThis =
                  controller.isConnected &&
                  controller.connectedDeviceAddress == address;

              return ListTile(
                leading: Icon(
                  Icons.devices,
                  color: isConnectedToThis ? Colors.green : null,
                ),
                title: Text(name),
                subtitle: Text(address),
                trailing: isConnectedToThis
                    ? TextButton(
                        onPressed: () {
                          debugPrint(
                            '[ConnectionPage] Disconnect button pressed for device: $name ($address)',
                          );
                          controller.disconnectFromDevice(device);
                        },
                        child: const Text(
                          "Disconnect",
                          style: TextStyle(color: Colors.red),
                        ),
                      )
                    : TextButton(
                        onPressed: () {
                          debugPrint(
                            '[ConnectionPage] Connect button pressed for device: $name ($address)',
                          );
                          controller.connectToDevice(device);
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
