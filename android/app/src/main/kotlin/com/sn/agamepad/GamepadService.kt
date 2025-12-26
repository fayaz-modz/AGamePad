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

        val sdpSettings =
                BluetoothHidDeviceAppSdpSettings(
                        "AGamepad",
                        "Android Gamepad",
                        "Android",
                        0x01,
                        reportDescriptor!!
                )

        val qosSettings =
                BluetoothHidDeviceAppQosSettings(
                        BluetoothHidDeviceAppQosSettings.SERVICE_BEST_EFFORT,
                        800,
                        9,
                        0,
                        11250,
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
    fun sendReport(buttons: Int, leftX: Int, leftY: Int, rightX: Int, rightY: Int, dpad: Int) {
        val report = ByteArray(8)
        report[0] = leftX.toByte()
        report[1] = leftY.toByte()
        report[2] = rightX.toByte()
        report[3] = rightY.toByte()
        report[4] = (buttons and 0xFF).toByte()
        report[5] = ((buttons shr 8) and 0xFF).toByte()
        report[6] = (dpad and 0x0F).toByte()

        bluetoothHidDevice?.connectedDevices?.forEach { device ->
            bluetoothHidDevice?.sendReport(device, 1, report.copyOfRange(0, 7))
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

        // If we were supposed to be registered but the proxy is gone, re-initialize
        if (wasRegistered && bluetoothHidDevice == null) {
            Log.w(TAG, "HID device proxy was lost! Re-initializing...")
            initialize(reportDescriptor)
        } else if (wasRegistered && bluetoothHidDevice != null) {
            // We have the proxy and were registered, try to re-register
            Log.w(
                    TAG,
                    "Was registered but may have lost registration. Attempting to re-register..."
            )
            registerApp()
        } else if (bluetoothHidDevice == null && bluetoothAdapter != null) {
            // Even if not registered, ensure we have the proxy
            Log.d(TAG, "No HID device proxy, ensuring it's set up...")
            bluetoothAdapter?.getProfileProxy(context, serviceListener, BluetoothProfile.HID_DEVICE)
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
