import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/connection_provider.dart';

class BluetoothStatusCard extends StatelessWidget {
  const BluetoothStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final connectionProvider = Provider.of<ConnectionProvider>(context);
    final isAdvertising = connectionProvider.isAdvertising;
    final isConnected = connectionProvider.isConnected;
    final deviceAddress = connectionProvider.connectedDeviceAddress;

    // Determine status color, text, and icon based on state
    List<Color> gradientColors;
    String statusText;
    IconData statusIcon;

    if (isConnected) {
      gradientColors = [const Color(0xFF2E7D32), const Color(0xFF43A047)]; // Green
      statusText = "Connected";
      statusIcon = Icons.link;
    } else if (isAdvertising) {
      gradientColors = [const Color(0xFF1565C0), const Color(0xFF1976D2)]; // Blue
      statusText = "Broadcasting";
      statusIcon = Icons.bluetooth_connected;
    } else {
      gradientColors = [const Color(0xFF424242), const Color(0xFF616161)]; // Grey
      statusText = "Offline";
      statusIcon = Icons.bluetooth_disabled;
    }

    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/connection');
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Status Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  statusIcon,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              // Text Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.description, size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            isConnected && deviceAddress != null 
                                ? deviceAddress
                                : "HID Gamepad",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Navigation Arrow
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.5),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
