package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/fatih/color"
)

const (
	UHIDDevicePath    = "/dev/uhid"
	UHIDModule        = "uhid"
	BroadcastInterval = 2 * time.Second // Broadcast every 2 seconds
	ConnectionTimeout = 5 * time.Second // Consider disconnected after 5 seconds of no input
)

type Config struct {
	BroadcastPort int
	UDPServerPort int
	DeviceName    string
	Verbose       bool
}

type DeviceInfo struct {
	IP         string `json:"ip"`
	DeviceName string `json:"device_name"`
	Timestamp  int64  `json:"timestamp"`
}

type UHIDServer struct {
	config        Config
	broadcastConn *net.UDPConn
	udpConn       *net.UDPConn
	uhidFile      *os.File
	deviceInfo    DeviceInfo
	running       bool
	descriptor    []byte
	descriptorSet bool
	deviceCreated bool
	lastInputTime time.Time
	connected     bool
}

func main() {
	config := Config{}
	flag.IntVar(&config.BroadcastPort, "bport", 2242, "UDP port for discovery broadcast")
	flag.IntVar(&config.UDPServerPort, "uport", 2243, "UDP port for gamepad input")
	flag.StringVar(&config.DeviceName, "name", "AGamePad-UDP", "Name of the device to advertise")
	flag.BoolVar(&config.Verbose, "v", false, "Enable verbose logging (all packets)")
	flag.Parse()

	color.Cyan("🎮 AGamePad UDP Server Starting...")

	server, err := NewUHIDServer(config)
	if err != nil {
		color.Red("❌ Failed to create server: %v", err)
		os.Exit(1)
	}

	if err := server.Start(); err != nil {
		color.Red("❌ Server failed: %v", err)
		os.Exit(1)
	}
}

func NewUHIDServer(config Config) (*UHIDServer, error) {
	// Get local IP address
	ip, err := getLocalIP()
	if err != nil {
		return nil, fmt.Errorf("failed to get local IP: %w", err)
	}

	server := &UHIDServer{
		config: config,
		deviceInfo: DeviceInfo{
			IP:         ip,
			DeviceName: config.DeviceName,
			Timestamp:  time.Now().Unix(),
		},
	}

	return server, nil
}

func (s *UHIDServer) Start() error {
	// Setup UHID device first
	if err := s.setupUHIDDevice(); err != nil {
		color.Yellow("⚠️  UHID device setup failed: %v (continuing without UHID)", err)
	}

	// Setup broadcast listener
	if err := s.setupBroadcastListener(); err != nil {
		return fmt.Errorf("failed to setup broadcast listener: %w", err)
	}

	// Setup UDP server
	if err := s.setupUDPServer(); err != nil {
		return fmt.Errorf("failed to setup UDP server: %w", err)
	}

	s.running = true
	color.Green("✅ Server started successfully!")
	color.Cyan("📡 Listening for discovery on port %d", s.config.BroadcastPort)
	color.Cyan("🎮 UDP server listening on port %d", s.config.UDPServerPort)
	color.Cyan("📱 Advertising as: %s (%s)", s.deviceInfo.DeviceName, s.deviceInfo.IP)

	// Handle graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	// Start active broadcasting
	go s.activeBroadcast()

	// Start reading UHID events from kernel
	if s.uhidFile != nil {
		go s.readUHIDEvents()
	}

	// Wait for shutdown signal
	<-sigChan
	color.Yellow("\n🛑 Shutting down server...")
	s.Stop()

	return nil
}

func (s *UHIDServer) Stop() {
	s.running = false

	if s.broadcastConn != nil {
		s.broadcastConn.Close()
	}

	if s.udpConn != nil {
		s.udpConn.Close()
	}

	// Destroy UHID device before closing the file
	if s.uhidFile != nil && s.deviceCreated {
		s.destroyUHIDDevice()
	}

	if s.uhidFile != nil {
		s.uhidFile.Close()
	}

	color.Green("✅ Server stopped gracefully")
}

func (s *UHIDServer) setupBroadcastListener() error {
	broadcastAddr, err := net.ResolveUDPAddr("udp", fmt.Sprintf(":%d", s.config.BroadcastPort))
	if err != nil {
		return fmt.Errorf("failed to resolve broadcast address: %w", err)
	}

	s.broadcastConn, err = net.ListenUDP("udp", broadcastAddr)
	if err != nil {
		return fmt.Errorf("failed to listen on broadcast port: %w", err)
	}

	// Enable broadcast
	if err := s.broadcastConn.SetReadBuffer(1024); err != nil {
		return fmt.Errorf("failed to set read buffer: %w", err)
	}

	go s.handleBroadcastMessages()

	return nil
}

func (s *UHIDServer) handleBroadcastMessages() {
	buffer := make([]byte, 1024)

	for s.running {
		n, addr, err := s.broadcastConn.ReadFromUDP(buffer)
		if err != nil {
			if s.running {
				color.Red("❌ Error reading broadcast message: %v", err)
			}
			continue
		}

		message := strings.TrimSpace(string(buffer[:n]))
		if s.config.Verbose {
			color.Magenta("📨 Received broadcast from %s: %s", addr, message)
		}

		// Check if it's a device discovery request
		if strings.ToLower(message) == "discover" || strings.Contains(message, "device_info") {
			s.respondToDiscovery(addr)
		}
	}
}

func (s *UHIDServer) respondToDiscovery(addr *net.UDPAddr) {
	s.deviceInfo.Timestamp = time.Now().Unix()

	response, err := json.Marshal(s.deviceInfo)
	if err != nil {
		color.Red("❌ Failed to marshal device info: %v", err)
		return
	}

	// Send response back to the requester
	_, err = s.broadcastConn.WriteToUDP(response, addr)
	if err != nil {
		color.Red("❌ Failed to send device info response: %v", err)
		return
	}

	color.Green("📤 Sent device info to %s: %s", addr, string(response))
}

func (s *UHIDServer) activeBroadcast() {
	ticker := time.NewTicker(BroadcastInterval)
	defer ticker.Stop()

	broadcastAddr, err := net.ResolveUDPAddr("udp", fmt.Sprintf("255.255.255.255:%d", s.config.BroadcastPort))
	if err != nil {
		color.Red("❌ Failed to resolve broadcast address: %v", err)
		return
	}

	for s.running {
		<-ticker.C

		addr, err := getLocalIP()
		if err == nil {
			s.deviceInfo.IP = addr
		}

		// Check if we should broadcast (not connected or timed out)
		now := time.Now()
		if !s.connected || now.Sub(s.lastInputTime) > ConnectionTimeout {
			if s.connected {
				color.Yellow("⚠️  Connection timeout, resuming broadcast...")
				s.connected = false
			}

			// Update timestamp and broadcast
			s.deviceInfo.Timestamp = now.Unix()
			response, err := json.Marshal(s.deviceInfo)
			if err != nil {
				color.Red("❌ Failed to marshal device info: %v", err)
				continue
			}

			_, err = s.broadcastConn.WriteToUDP(response, broadcastAddr)
			if err != nil {
				color.Red("❌ Failed to broadcast device info: %v", err)
			} else if s.config.Verbose {
				color.Cyan("📡 Broadcasting: %s", string(response))
			}
		}
	}
}

func (s *UHIDServer) setupUHIDDevice() error {
	// First, just try to open the device. If it works, we don't care about modules.
	file, err := os.OpenFile(UHIDDevicePath, os.O_RDWR, 0)
	if err == nil {
		s.uhidFile = file
		color.Green("✅ UHID device opened successfully (pre-existing)")
		return nil
	}

	// If opening failed, maybe we need to load the module or create the node.
	color.Yellow("⚠️  Could not open UHID device directly: %v. Attempting setup...", err)

	// Check if UHID module is loaded, load it if not
	if !s.isUHIDModuleLoaded() {
		color.Yellow("⚠️  UHID module not loaded, attempting to load...")
		// We ignore the error here because on Android/Built-in kernels modprobe might fail
		// but the functionality might still be available or we might not have permissions to modprobe.
		if err := s.loadUHIDModule(); err != nil {
			color.Yellow("⚠️  Failed to load UHID module: %v (proceeding anyway in case it's built-in)", err)
		} else {
			color.Green("✅ UHID module loaded successfully")
		}
	}

	// Check if UHID device exists, create it if not
	if _, err := os.Stat(UHIDDevicePath); os.IsNotExist(err) {
		color.Yellow("⚠️  UHID device not found, attempting to create...")
		if err := s.createUHIDDevice(); err != nil {
			return fmt.Errorf("failed to create UHID device: %w", err)
		}
		color.Green("✅ UHID device created successfully")
	}

	// Try to open UHID device again
	file, err = os.OpenFile(UHIDDevicePath, os.O_RDWR, 0)
	if err != nil {
		return fmt.Errorf("failed to open UHID device: %w", err)
	}

	s.uhidFile = file
	color.Green("✅ UHID device opened successfully")

	return nil
}

func (s *UHIDServer) isUHIDModuleLoaded() bool {
	data, err := os.ReadFile("/proc/modules")
	if err != nil {
		return false
	}

	return strings.Contains(string(data), UHIDModule)
}

func (s *UHIDServer) loadUHIDModule() error {
	cmd := exec.Command("modprobe", UHIDModule)
	return cmd.Run()
}

func (s *UHIDServer) createUHIDDevice() error {
	// Try to create the device node
	cmd := exec.Command("mknod", UHIDDevicePath, "c", "10", "223")
	err := cmd.Run()
	if err != nil {
		// If mknod fails, try with different permissions
		cmd = exec.Command("sudo", "mknod", UHIDDevicePath, "c", "10", "223")
		err = cmd.Run()
		if err != nil {
			return fmt.Errorf("failed to create device node: %w", err)
		}
	}

	// Set permissions
	cmd = exec.Command("chmod", "666", UHIDDevicePath)
	err = cmd.Run()
	if err != nil {
		cmd = exec.Command("sudo", "chmod", "666", UHIDDevicePath)
		err = cmd.Run()
		if err != nil {
			color.Yellow("⚠️  Failed to set permissions on UHID device: %v", err)
		}
	}

	return nil
}

func (s *UHIDServer) setupUDPServer() error {
	udpAddr, err := net.ResolveUDPAddr("udp", fmt.Sprintf(":%d", s.config.UDPServerPort))
	if err != nil {
		return fmt.Errorf("failed to resolve UDP address: %w", err)
	}

	s.udpConn, err = net.ListenUDP("udp", udpAddr)
	if err != nil {
		return fmt.Errorf("failed to listen on UDP port: %w", err)
	}

	go s.handleUDPMessages()

	return nil
}

func (s *UHIDServer) handleUDPMessages() {
	buffer := make([]byte, 2048) // Increased buffer for descriptors

	for s.running {
		n, addr, err := s.udpConn.ReadFromUDP(buffer)
		if err != nil {
			if s.running {
				color.Red("❌ Error reading UDP message: %v", err)
			}
			continue
		}

		data := buffer[:n]

		// Check if this is a descriptor packet (starts with magic)
		if n > 4 && string(data[:4]) == "DESC" {
			s.handleDescriptorPacket(data[4:], addr)
		} else if n == 8 || n == 10 {
			// Process raw gamepad input (8 bytes for Classic/BLE, 10 bytes for UDP enhanced)
			s.processGamepadInput(data, addr)
		} else {
			color.Yellow("⚠️  Received %d bytes from %s, expected 8, 10 or descriptor", n, addr)
		}
	}
}

func (s *UHIDServer) handleDescriptorPacket(data []byte, addr *net.UDPAddr) {
	color.Cyan("📋 Received HID descriptor from %s (%d bytes)", addr, len(data))
	color.Cyan("   Descriptor bytes: %X", data)

	// Store the descriptor
	s.descriptor = make([]byte, len(data))
	copy(s.descriptor, data)
	s.descriptorSet = true

	// Create UHID device with the descriptor (only once)
	if s.uhidFile != nil && !s.deviceCreated {
		color.Cyan("🔧 Creating UHID device with descriptor...")
		err := s.createUHIDDeviceWithDescriptor(data)
		if err != nil {
			color.Red("❌ Failed to create UHID device: %v", err)
		} else {
			color.Green("✅ UHID device created successfully")
			s.deviceCreated = true
		}
	} else if s.deviceCreated {
		color.Cyan("ℹ️  UHID device already created, skipping")
	} else {
		color.Yellow("⚠️  UHID file not available, skipping device creation")
	}

	// Send acknowledgment back
	ack := []byte("DESC_OK")
	_, err := s.udpConn.WriteToUDP(ack, addr)
	if err != nil {
		color.Red("❌ Failed to send descriptor acknowledgment: %v", err)
	} else {
		color.Green("📤 Sent descriptor acknowledgment to %s", addr)
	}
}

func (s *UHIDServer) createUHIDDeviceWithDescriptor(descriptor []byte) error {
	// UHID_CREATE2 event structure
	// struct uhid_event {
	//   __u32 type;
	//   union {
	//     struct uhid_create2_req create2;
	//     ...
	//   } u;
	// };

	const UHID_CREATE2 = 11
	const maxDescriptorSize = 4096
	const nameSize = 128

	if len(descriptor) > maxDescriptorSize {
		return fmt.Errorf("descriptor too large: %d bytes (max %d)", len(descriptor), maxDescriptorSize)
	}

	// Create the event buffer
	// type (4) + name (128) + phys (64) + uniq (64) + rd_size (2) + bus (2) + vendor (4) + product (4) + version (4) + country (4) + rd_data (4096)
	eventSize := 4 + 128 + 64 + 64 + 2 + 2 + 4 + 4 + 4 + 4 + maxDescriptorSize
	event := make([]byte, eventSize)

	// Set event type (UHID_CREATE2 = 11)
	event[0] = UHID_CREATE2
	event[1] = 0
	event[2] = 0
	event[3] = 0

	// Device name
	name := "AGamePad Virtual Controller"
	copy(event[4:4+nameSize], []byte(name))

	// phys (physical location) - offset 4 + 128 = 132
	phys := "uhid-agamepad"
	copy(event[132:132+64], []byte(phys))

	// uniq (unique identifier) - offset 132 + 64 = 196
	uniq := "agamepad-001"
	copy(event[196:196+64], []byte(uniq))

	// rd_size (descriptor size) - offset 196 + 64 = 260 (uint16 little-endian)
	descSize := uint16(len(descriptor))
	event[260] = byte(descSize & 0xFF)
	event[261] = byte((descSize >> 8) & 0xFF)

	// bus - offset 262 (USB = 0x03, Bluetooth = 0x05)
	event[262] = 0x03 // USB
	event[263] = 0x00

	// vendor ID - offset 264 (uint32 little-endian)
	vendor := uint32(0x046d) // Logitech vendor ID (matches BLE service)
	event[264] = byte(vendor & 0xFF)
	event[265] = byte((vendor >> 8) & 0xFF)
	event[266] = byte((vendor >> 16) & 0xFF)
	event[267] = byte((vendor >> 24) & 0xFF)

	// product ID - offset 268
	product := uint32(0x0000) // Generic product ID
	event[268] = byte(product & 0xFF)
	event[269] = byte((product >> 8) & 0xFF)
	event[270] = byte((product >> 16) & 0xFF)
	event[271] = byte((product >> 24) & 0xFF)

	// version - offset 272
	version := uint32(0x0100)
	event[272] = byte(version & 0xFF)
	event[273] = byte((version >> 8) & 0xFF)
	event[274] = byte((version >> 16) & 0xFF)
	event[275] = byte((version >> 24) & 0xFF)

	// country - offset 276
	country := uint32(0)
	event[276] = byte(country & 0xFF)
	event[277] = byte((country >> 8) & 0xFF)
	event[278] = byte((country >> 16) & 0xFF)
	event[279] = byte((country >> 24) & 0xFF)

	// rd_data (descriptor) - offset 280
	copy(event[280:280+len(descriptor)], descriptor)

	color.Cyan("📝 UHID CREATE2 event details:")
	color.Cyan("   Event type: %d (UHID_CREATE2)", UHID_CREATE2)
	color.Cyan("   Device name: %s", name)
	color.Cyan("   Vendor:Product: 0x%04X:0x%04X", vendor, product)
	color.Cyan("   Descriptor size: %d bytes", descSize)
	color.Cyan("   Event total size: %d bytes", len(event))

	// Write the event to UHID
	n, err := s.uhidFile.Write(event)
	if err != nil {
		return fmt.Errorf("failed to write UHID_CREATE2 event: %w", err)
	}

	color.Green("✅ Written %d bytes to UHID device", n)
	return nil
}

func (s *UHIDServer) destroyUHIDDevice() error {
	const UHID_DESTROY = 1

	// Create a simple event with just the type
	event := make([]byte, 4)
	event[0] = UHID_DESTROY
	event[1] = 0
	event[2] = 0
	event[3] = 0

	_, err := s.uhidFile.Write(event)
	if err != nil {
		color.Red("❌ Failed to send UHID_DESTROY: %v", err)
		return err
	}

	color.Green("✅ UHID device destroyed")
	s.deviceCreated = false
	return nil
}

func (s *UHIDServer) readUHIDEvents() {
	const eventSize = 4380 // sizeof(struct uhid_event)
	buffer := make([]byte, eventSize)

	color.Cyan("📖 Started reading UHID events from kernel...")

	for s.running {
		n, err := s.uhidFile.Read(buffer)
		if err != nil {
			if s.running {
				color.Yellow("⚠️  Error reading UHID event: %v", err)
			}
			continue
		}

		if n < 4 {
			continue
		}

		// Extract event type from first 4 bytes (little endian)
		eventType := uint32(buffer[0]) | uint32(buffer[1])<<8 | uint32(buffer[2])<<16 | uint32(buffer[3])<<24

		// Log important events
		switch eventType {
		case 0: // UHID_START
			color.Green("🚀 UHID device started by kernel")
		case 1: // UHID_STOP
			color.Yellow("⏸️  UHID device stopped by kernel")
		case 5: // UHID_OPEN
			color.Green("📂 UHID device opened by application")
		case 6: // UHID_CLOSE
			color.Yellow("📪 UHID device closed by application")
		case 7: // UHID_OUTPUT
			color.Cyan("📤 Received OUTPUT event from kernel (%d bytes)", n)
		case 8: // UHID_GET_REPORT
			color.Cyan("📥 Kernel requested GET_REPORT")
		case 9: // UHID_SET_REPORT
			color.Cyan("📥 Kernel requested SET_REPORT")
		default:
			// Don't log unknown events to avoid spam
		}
	}

	color.Yellow("📖 Stopped reading UHID events")
}

func (s *UHIDServer) processGamepadInput(data []byte, addr *net.UDPAddr) {
	// Update connection state
	s.lastInputTime = time.Now()
	if !s.connected {
		s.connected = true
		color.Green("✅ Device connected from %s", addr)
	}

	// Check if UHID device is ready
	if s.uhidFile == nil {
		color.Yellow("⚠️  UHID file not available, ignoring input")
		return
	}

	if !s.deviceCreated {
		color.Yellow("⚠️  UHID device not created yet, ignoring input")
		return
	}

	// Forward to UHID device
	{
		const UHID_INPUT2 = 12
		const maxDescriptorSize = 4096

		// Validate input data
		if len(data) < 1 {
			color.Red("❌ Invalid input data: too short")
			return
		}

		color.Cyan("   Packet data (%d bytes): %X", len(data), data)

		// struct uhid_input2_req {
		//   __u16 size;              // at offset 4-5
		//   __u8 data[UHID_DATA_MAX]; // at offset 6+
		// }
		// The data field includes the report ID as the first byte!
		// Our packet already has: [ReportID] [axes...] [buttons...] [dpad]

		// Calculate the size of the event structure
		eventSize := 4 + 128 + 64 + 64 + 2 + 2 + 4 + 4 + 4 + 4 + maxDescriptorSize
		event := make([]byte, eventSize)

		// Set event type (UHID_INPUT2 = 12)
		event[0] = UHID_INPUT2
		event[1] = 0
		event[2] = 0
		event[3] = 0

		// Size at offset 4-5 (uint16 little-endian)
		// Size includes the entire data including report ID
		dataLen := uint16(len(data))
		event[4] = byte(dataLen & 0xFF)
		event[5] = byte((dataLen >> 8) & 0xFF)

		// Data at offset 6 (includes report ID as first byte)
		copy(event[6:], data)

		_, err := s.uhidFile.Write(event)
		if err != nil {
			color.Red("❌ Failed to write to UHID device: %v", err)
		} else if s.config.Verbose {
			color.Green("✅ Forwarded %d bytes (with report ID %d) to UHID device", len(data), data[0])
		}
	}
}

func getLocalIP() (string, error) {
	// Try to get a non-loopback interface
	interfaces, err := net.Interfaces()
	if err != nil {
		return "", err
	}

	for _, iface := range interfaces {
		// Skip down interfaces and loopback
		if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 {
			continue
		}

		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}

		for _, addr := range addrs {
			var ip net.IP
			switch v := addr.(type) {
			case *net.IPNet:
				ip = v.IP
			case *net.IPAddr:
				ip = v.IP
			}

			// We want IPv4 and not loopback
			if ip != nil && ip.To4() != nil && !ip.IsLoopback() {
				return ip.String(), nil
			}
		}
	}

	// Fallback to localhost
	return "127.0.0.1", nil
}
