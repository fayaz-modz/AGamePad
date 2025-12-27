# AGamePad UHID Server

UDP-based gamepad server that creates a virtual HID gamepad device on Linux using UHID (User-space HID).

## Features

- 🎮 Virtual gamepad device via UHID
- 📡 UDP-based communication
- 🔍 Auto-discovery via broadcast
- 🔄 Real-time input forwarding
- ✅ Support for 16 buttons, 2 analog sticks, and D-pad

## Requirements

### Linux
- Linux kernel with UHID support (usually built-in)
- `/dev/uhid` access (requires root or udev rules)
- Go 1.16 or later

### Android (for building Android binaries)
- Android NDK (tested with 27.2.12479018)
- Go 1.16 or later with CGO support

## Building

### For Linux (Native)

```bash
# Build
make linux

# Or simply
make

# Install system-wide
sudo make install
```

The binary will be created at `build/uhid_server-linux`.

### For Android

```bash
# Set NDK path (if not already in environment)
export ANDROID_NDK_HOME=~/Android/Sdk/ndk/27.2.12479018

# Build for ARM64 (most common)
make android-arm64

# Build for all architectures
make android-all
```

Available Android targets:
- `android-arm64` - 64-bit ARM (most modern devices)
- `android-arm` - 32-bit ARM (older devices)
- `android-x86_64` - 64-bit x86 (emulators)
- `android-x86` - 32-bit x86 (old emulators)

### Build Output

All binaries are created in the `build/` directory:
- `uhid_server-linux` - Linux native binary
- `uhid_server-android-arm64` - Android ARM64 binary
- `uhid_server-android-arm` - Android ARM binary
- etc.

## Running

### On Linux

```bash
# Run with root privileges (required for UHID)
sudo ./build/uhid_server-linux

# Or if installed system-wide
sudo uhid_server
```

### On Android (Termux)

```bash
# Push to device
adb push build/uhid_server-android-arm64 /data/local/tmp/uhid_server
adb shell chmod +x /data/local/tmp/uhid_server

# Run with root
adb shell
su
/data/local/tmp/uhid_server
```

## Network Configuration

The server uses two UDP ports:
- **Port 2242** - Broadcast discovery
- **Port 2243** - Gamepad input data

Make sure these ports are not blocked by your firewall.

## Usage

1. **Start the server:**
   ```bash
   sudo ./uhid_server
   ```

2. **The server will:**
   - Create a virtual gamepad device
   - Start broadcasting its presence
   - Listen for connections from the mobile app

3. **Connect from your phone:**
   - Open the AGamePad mobile app
   - The server should appear in device discovery
   - Tap to connect

4. **Verify the device:**
   ```bash
   # List input devices
   cat /sys/class/input/event*/device/name | grep AGamePad
   
   # Test with evtest
   sudo evtest /dev/input/eventXX  # Replace XX with your event number
   ```

## Troubleshooting

### Permission Denied on /dev/uhid

The server needs access to `/dev/uhid`. Either:

1. **Run with sudo** (quick solution):
   ```bash
   sudo ./uhid_server
   ```

2. **Create udev rule** (permanent solution):
   ```bash
   # Create rule file
   sudo nano /etc/udev/rules.d/99-uhid.rules
   
   # Add this line:
   KERNEL=="uhid", MODE="0666"
   
   # Reload udev
   sudo udevadm control --reload-rules
   sudo udevadm trigger
   ```

### Device Not Appearing

- Check if UHID module is loaded: `lsmod | grep uhid`
- Load if needed: `sudo modprobe uhid`
- Check dmesg for errors: `dmesg | tail -20`

### Connection Issues

- Verify both devices are on the same network
- Check firewall settings (ports 2242, 2243)
- Look for broadcast messages in server output

## Development

### Project Structure

- `uhid_server.go` - Main server implementation
- `go.mod` - Go module definition
- `Makefile` - Build system

### Key Components

1. **UHID Device Creation** - Creates virtual HID gamepad
2. **UDP Broadcast** - Device discovery mechanism
3. **Input Processing** - Receives and forwards gamepad input
4. **Event Handling** - Bidirectional UHID communication

### Debugging

Enable verbose logging by checking server output. The server logs:
- 🎮 Input packets received
- ✅ UHID events (device start, open, close)
- 📡 Network activity
- ❌ Errors and warnings

## Technical Details

### HID Descriptor

The server uses a standard gamepad HID descriptor with:
- 4 analog axes (2 sticks with X, Y each)
- 16 buttons
- 8-direction D-pad (hat switch)

### Packet Format

UDP input packets (8 bytes):
```
[0] - Report ID (0x01)
[1] - Left stick X (0-255)
[2] - Left stick Y (0-255)
[3] - Right stick X (0-255)
[4] - Right stick Y (0-255)
[5] - Buttons (low byte)
[6] - Buttons (high byte)
[7] - D-pad direction (0-7, 8=center)
```

## License

Part of the AGamePad project. See main project README for license information.

## Contributing

Contributions welcome! Please test changes on both Linux and Android before submitting.

## Support

For issues, questions, or contributions, please refer to the main AGamePad project repository.
