package com.sn.agamepad

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothHidDevice
import android.bluetooth.BluetoothHidDeviceAppQosSettings
import android.bluetooth.BluetoothHidDeviceAppSdpSettings
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.util.Log
import java.util.ArrayList
import java.util.concurrent.Executor
import kotlin.collections.List
import kotlin.collections.Map
import kotlin.collections.mapOf

class GamepadService(private val context: Context) {
    private val TAG = "GamepadService"
    private var bluetoothHidDevice: BluetoothHidDevice? = null
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var wasRegistered = false // Track if we were registered before

    private var reportDescriptor: ByteArray? = null

    var listener: GamepadServiceListener? = null

    interface GamepadServiceListener {
        fun onConnectionStateChanged(deviceAddr: String, state: Int)
        fun onAppStatusChanged(registered: Boolean)
    }

    private val callback =
            object : BluetoothHidDevice.Callback() {
                override fun onAppStatusChanged(
                        pluggedDevice: BluetoothDevice?,
                        registered: Boolean
                ) {
                    Log.d(
                            TAG,
                            "onAppStatusChanged: registered=$registered, device=${pluggedDevice?.address}"
                    )
                    // Only update wasRegistered if we actually got a 'true' or if we were
                    // explicitly stopping.
                    // This avoids overwriting true with false during transient screen off states if
                    // we don't want to.
                    // However, for consistency with Flutter side:
                    wasRegistered = registered
                    listener?.onAppStatusChanged(registered)
                }

                override fun onConnectionStateChanged(device: BluetoothDevice?, state: Int) {
                    Log.d(TAG, "onConnectionStateChanged: device=${device?.address}, state=$state")
                    device?.let { listener?.onConnectionStateChanged(it.address, state) }
                }
            }

    private val serviceListener =
            object : BluetoothProfile.ServiceListener {
                override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                    Log.d(TAG, "onServiceConnected: profile=$profile")
                    if (profile == BluetoothProfile.HID_DEVICE) {
                        bluetoothHidDevice = proxy as BluetoothHidDevice
                        Log.d(TAG, "BluetoothHidDevice proxy obtained, calling registerApp()")
                        registerApp()
                    }
                }

                override fun onServiceDisconnected(profile: Int) {
                    Log.d(TAG, "onServiceDisconnected: profile=$profile")
                    if (profile == BluetoothProfile.HID_DEVICE) {
                        bluetoothHidDevice = null
                        Log.w(TAG, "BluetoothHidDevice proxy lost!")
                    }
                }
            }

    fun initialize(descriptor: ByteArray?) {
        Log.d(TAG, "initialize() called with descriptor size: ${descriptor?.size ?: 0}")
        this.reportDescriptor = descriptor

        val bluetoothManager =
                context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter

        if (bluetoothAdapter == null) {
            Log.e(TAG, "BluetoothAdapter is null! Device may not support Bluetooth")
            return
        }

        Log.d(TAG, "Getting BluetoothHidDevice profile proxy...")
        val success =
                bluetoothAdapter?.getProfileProxy(
                        context,
                        serviceListener,
                        BluetoothProfile.HID_DEVICE
                )
        Log.d(TAG, "getProfileProxy returned: $success")
    }

    @SuppressLint("MissingPermission")
    fun connect(address: String) {
        Log.d(TAG, "connect() called for address: $address")
        if (bluetoothAdapter == null) {
            Log.e(TAG, "connect: BluetoothAdapter is null")
            return
        }
        if (bluetoothHidDevice == null) {
            Log.e(TAG, "connect: BluetoothHidDevice is null. Was initialize() called?")
            return
        }

        val device = bluetoothAdapter?.getRemoteDevice(address)
        if (device != null) {
            Log.d(TAG, "Calling bluetoothHidDevice.connect() for ${device.name} ($address)")
            val result = bluetoothHidDevice?.connect(device)
            Log.d(TAG, "connect() result: $result")
        } else {
            Log.e(TAG, "Could not get remote device for address: $address")
        }
    }

    @SuppressLint("MissingPermission")
    fun disconnect(address: String) {
        Log.d(TAG, "disconnect() called for address: $address")
        if (bluetoothAdapter == null) {
            Log.e(TAG, "disconnect: BluetoothAdapter is null")
            return
        }
        if (bluetoothHidDevice == null) {
            Log.e(TAG, "disconnect: BluetoothHidDevice is null")
            return
        }

        val device = bluetoothAdapter?.getRemoteDevice(address)
        if (device != null) {
            Log.d(TAG, "Calling bluetoothHidDevice.disconnect() for ${device.name} ($address)")
            val result = bluetoothHidDevice?.disconnect(device)
            Log.d(TAG, "disconnect() result: $result")
        } else {
            Log.e(TAG, "Could not get remote device for address: $address")
        }
    }

    @SuppressLint("MissingPermission")
    fun getPairedDevices(): List<Map<String, String>> {
        Log.d(TAG, "getPairedDevices() called")
        val devices = ArrayList<Map<String, String>>()
        try {
            if (bluetoothAdapter == null) {
                Log.e(TAG, "getPairedDevices: BluetoothAdapter is null")
                return devices
            }

            val bondedDevices = bluetoothAdapter?.bondedDevices
            Log.d(TAG, "Found ${bondedDevices?.size ?: 0} bonded devices")

            bondedDevices?.forEach { device ->
                val name = device.name ?: "Unknown"
                val address = device.address
                Log.d(TAG, "  Device: $name ($address)")
                devices.add(mapOf("name" to name, "address" to address))
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Permission missing for getPairedDevices", e)
        } catch (e: Exception) {
            Log.e(TAG, "Error in getPairedDevices", e)
        }
        return devices
    }

    @SuppressLint("MissingPermission")
    private fun registerApp() {
        Log.d(TAG, "registerApp() called")

        if (bluetoothHidDevice == null) {
            Log.e(TAG, "registerApp: BluetoothHidDevice is null, cannot register")
            return
        }

        if (reportDescriptor == null) {
            Log.e(TAG, "registerApp: reportDescriptor is null, cannot register")
            return
        }

        // Subclass 0x08 is Gamepad (0x04 is Joystick)
        // Reference: Bluetooth HID Spec subclass byte
        val sdpSettings =
                BluetoothHidDeviceAppSdpSettings(
                        "AGamepad",
                        "Android Gamepad",
                        "Android",
                        0x08, // Subclass: Gamepad (0x08).
                        reportDescriptor!!
                )

        val qosSettings =
                BluetoothHidDeviceAppQosSettings(
                        BluetoothHidDeviceAppQosSettings.SERVICE_GUARANTEED,
                        4000, // tokenRate: increased for higher throughput
                        9, // tokenBucketSize
                        0, // peakBandwidth: 0 = no limit
                        1250, // latency: 1.25ms (was 11.25ms)
                        BluetoothHidDeviceAppQosSettings.MAX
                )

        Log.d(TAG, "Calling bluetoothHidDevice.registerApp()")
        val result =
                bluetoothHidDevice?.registerApp(
                        sdpSettings,
                        null,
                        qosSettings,
                        Executor { it.run() },
                        callback
                )
        Log.d(TAG, "registerApp() result: $result")
    }

    @SuppressLint("MissingPermission")
    fun requestDiscoverable(duration: Int): Boolean {
        Log.d(TAG, "requestDiscoverable() called with duration: $duration")
        if (bluetoothAdapter == null) return false

        // Attempt to set CoD to Gamepad before making discoverable
        setGamepadClassOfDevice()

        // We can't directly trigger the intent here as we need Activity context,
        // but we can return true to signal MainActivity to do it.
        return true
    }

    /**
     * Attempts to set the Bluetooth Class of Device (CoD) to Gamepad (0x002508). This uses
     * reflection to call hidden Android APIs.
     *
     * CoD breakdown for 0x002508:
     * - Major Service Class: 0x00 (None)
     * - Major Device Class: 0x05 (Peripheral)
     * - Minor Device Class: 0x08 (Gamepad)
     *
     * Note: This may not work on all devices due to:
     * - Hidden API restrictions (Android 9+)
     * - Manufacturer-specific Bluetooth stack implementations
     * - Missing system permissions
     */
    @SuppressLint("MissingPermission", "DiscouragedPrivateApi")
    private fun setGamepadClassOfDevice() {
        try {
            // CoD for Gamepad: 0x002508
            // Format: Major Service Class (bits 13-23) | Major Device Class (bits 8-12) | Minor
            // Device Class (bits 2-7)
            // Peripheral (0x05) = Major, Gamepad (0x02) = Minor within Peripheral
            // Full CoD value: 0x002508 = 0b0000000000100101_00001000
            val gamepadCoD = 0x002508

            Log.d(
                    TAG,
                    "Attempting to set Class of Device to Gamepad (0x${Integer.toHexString(gamepadCoD)})"
            )

            // Method 1: Try using setClass method via reflection
            try {
                val setClassMethod =
                        bluetoothAdapter?.javaClass?.getDeclaredMethod(
                                "setClass",
                                Int::class.java,
                                Int::class.java
                        )
                setClassMethod?.isAccessible = true
                // Major class 0x05 (Peripheral), Minor class 0x08 (Gamepad within Peripheral)
                val result = setClassMethod?.invoke(bluetoothAdapter, 0x05, 0x02)
                Log.d(TAG, "setClass method result: $result")
            } catch (e: NoSuchMethodException) {
                Log.d(TAG, "setClass method not found, trying alternative...")
            } catch (e: Exception) {
                Log.w(TAG, "setClass method failed: ${e.message}")
            }

            // Method 2: Try writing to Bluetooth config (if accessible)
            try {
                val method =
                        bluetoothAdapter?.javaClass?.getDeclaredMethod(
                                "setScanMode",
                                Int::class.java,
                                Int::class.java
                        )
                // Just log that we tried - this doesn't actually set CoD but doesn't hurt
                Log.d(TAG, "Scan mode method available for potential CoD setting")
            } catch (e: Exception) {
                // Expected to fail, just logging
            }

            // Method 3: On some Samsung/Qualcomm devices, the CoD is set when HID is registered
            // The SDP settings subclass 0x08 should influence this
            Log.d(
                    TAG,
                    "Note: HID device registration with subclass 0x08 should influence discovery appearance"
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set Class of Device: ${e.message}")
        }
    }

    @SuppressLint("MissingPermission")
    fun setBluetoothName(name: String): Boolean {
        Log.d(TAG, "setBluetoothName() called with: $name")
        if (bluetoothAdapter == null) return false
        return try {
            val success = bluetoothAdapter?.setName(name) ?: false
            Log.d(TAG, "setName result: $success")
            success
        } catch (e: Exception) {
            Log.e(TAG, "Error setting Bluetooth name", e)
            false
        }
    }

    @SuppressLint("MissingPermission")
    fun getBluetoothName(): String {
        return bluetoothAdapter?.name ?: "Unknown"
    }

    @SuppressLint("MissingPermission")
    fun sendRawReport(id: Int, report: ByteArray) {
        val hid = bluetoothHidDevice ?: return
        val devices = hid.connectedDevices
        if (devices.isEmpty()) return

        // Send report to all connected devices - simple and fast
        // Packet bursting was causing queue congestion and adding latency
        for (device in devices) {
            hid.sendReport(device, id, report)
        }
    }

    /**
     * Check and restore the HID device state if needed. This is called when the app resumes (e.g.,
     * screen turns back on) to recover from situations where the HID proxy was lost.
     */
    fun checkAndRestoreState() {
        Log.d(
                TAG,
                "checkAndRestoreState() called - wasRegistered=$wasRegistered, bluetoothHidDevice=${bluetoothHidDevice != null}"
        )

        if (bluetoothHidDevice == null && bluetoothAdapter != null) {
            // Priority 1: Ensure we have the proxy
            Log.d(TAG, "No HID device proxy, requesting it...")
            bluetoothAdapter?.getProfileProxy(context, serviceListener, BluetoothProfile.HID_DEVICE)
        } else if (wasRegistered && bluetoothHidDevice != null) {
            // Priority 2: If we were registered but suspect we might need a refresh.
            // Note: Calling registerApp() if already registered will often return false.
            // Ideally we only call this if we know for sure we aren't registered.
            // But Android doesn't give us a direct way to check.
            // For now, let's only re-register if we don't have connected devices or some other
            // hint?
            // Actually, let's just log and trust the current proxy state for now unless it
            // explicitly disconnected.
            Log.d(TAG, "State looks consistent (wasRegistered and have proxy)")
        } else {
            Log.d(TAG, "State looks good, no action needed")
        }
    }

    fun stop() {
        Log.d(TAG, "stop() called")
        @SuppressLint("MissingPermission")
        if (bluetoothHidDevice != null) {
            Log.d(TAG, "Calling bluetoothHidDevice.unregisterApp()")
            bluetoothHidDevice?.unregisterApp()
            try {
                Log.d(TAG, "Closing profile proxy")
                bluetoothAdapter?.closeProfileProxy(BluetoothProfile.HID_DEVICE, bluetoothHidDevice)
            } catch (e: Exception) {
                Log.e(TAG, "Error closing profile proxy", e)
            }
            bluetoothHidDevice = null
            Log.d(TAG, "BluetoothHidDevice cleared")
        } else {
            Log.w(TAG, "stop() called but bluetoothHidDevice is already null")
        }
    }
}
