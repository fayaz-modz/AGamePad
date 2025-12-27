package com.sn.agamepad

import android.bluetooth.BluetoothAdapter
import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import kotlin.collections.mapOf

class MainActivity :
        FlutterActivity(),
        GamepadService.GamepadServiceListener,
        BleGamepadService.BleGamepadServiceListener {

    private val TAG = "MainActivity"
    private val CHANNEL = "com.sn.agamepad/gamepad"

    private lateinit var classicGamepadService: GamepadService
    private lateinit var bleGamepadService: BleGamepadService
    private var methodChannel: MethodChannel? = null

    // Current mode: "classic" or "ble"
    private var currentMode: String = "classic"
    private var isInitialized: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        classicGamepadService = GamepadService(this)
        classicGamepadService.listener = this

        bleGamepadService = BleGamepadService(this)
        bleGamepadService.listener = this
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "configureFlutterEngine called")

        // High-frequency direct binary handler for input reports
        flutterEngine.dartExecutor.binaryMessenger.setMessageHandler(
                "com.sn.agamepad/gamepad/raw",
                object : BinaryMessenger.BinaryMessageHandler {
                    override fun onMessage(
                            message: ByteBuffer?,
                            callback: BinaryMessenger.BinaryReply
                    ) {
                        if (message != null) {
                            val bytes = ByteArray(message.remaining())
                            message.get(bytes)
                            sendRawReport(bytes)
                        }
                        callback.reply(null)
                    }
                }
        )

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            // Skip logging for high-frequency sendInput calls to avoid latency
            if (call.method != "sendInput" && call.method != "sendRawReport") {
                Log.d(TAG, "Method call received: ${call.method}")
            }
            when (call.method) {
                "initialize" -> {
                    val descriptor = call.argument<ByteArray>("descriptor")
                    val mode = call.argument<String>("mode") ?: "classic"
                    Log.d(TAG, "Initialize called with mode: $mode")
                    initialize(descriptor, mode)
                    result.success(null)
                }
                "sendInput", "sendRawReport" -> {
                    val report = call.arguments as? ByteArray
                    if (report != null) {
                        sendRawReport(report)
                    } else {
                        // Fallback for old sendInput format if still used
                        val buttons = call.argument<Int>("buttons") ?: 0
                        val lx = call.argument<Int>("lx") ?: 127
                        val ly = call.argument<Int>("ly") ?: 127
                        val rx = call.argument<Int>("rx") ?: 127
                        val ry = call.argument<Int>("ry") ?: 127
                        val dpad = call.argument<Int>("dpad") ?: 8

                        val bytes = ByteArray(7)
                        bytes[0] = lx.toByte()
                        bytes[1] = ly.toByte()
                        bytes[2] = rx.toByte()
                        bytes[3] = ry.toByte()
                        bytes[4] = (buttons and 0xFF).toByte()
                        bytes[5] = ((buttons shr 8) and 0xFF).toByte()
                        bytes[6] = dpad.toByte()
                        sendRawReport(bytes)
                    }
                    result.success(null)
                }
                "stop" -> {
                    Log.d(TAG, "Calling stop()")
                    stop()
                    result.success(null)
                }
                "setMode" -> {
                    val mode = call.argument<String>("mode") ?: "classic"
                    Log.d(TAG, "setMode called with: $mode")
                    setMode(mode)
                    result.success(null)
                }
                "getMode" -> {
                    result.success(currentMode)
                }
                "getPairedDevices" -> {
                    Log.d(TAG, "Calling getPairedDevices()")
                    val devices = classicGamepadService.getPairedDevices()
                    Log.d(TAG, "getPairedDevices returned ${devices.size} devices")
                    result.success(devices)
                }
                "connect" -> {
                    val address = call.argument<String>("address")
                    Log.d(TAG, "Connect called for address: $address")
                    if (address != null) {
                        // Connect only works for classic mode
                        if (currentMode == "classic") {
                            classicGamepadService.connect(address)
                        }
                        result.success(null)
                    } else {
                        Log.e(TAG, "Connect: Address is null")
                        result.error("INVALID_ARGUMENT", "Address cannot be null", null)
                    }
                }
                "disconnect" -> {
                    val address = call.argument<String>("address")
                    Log.d(TAG, "Disconnect called for address: $address")
                    if (address != null) {
                        if (currentMode == "classic") {
                            classicGamepadService.disconnect(address)
                        }
                        result.success(null)
                    } else {
                        Log.e(TAG, "Disconnect: Address is null")
                        result.error("INVALID_ARGUMENT", "Address cannot be null", null)
                    }
                }
                "setBluetoothName" -> {
                    val name = call.argument<String>("name")
                    Log.d(TAG, "setBluetoothName called: $name")
                    if (name != null) {
                        val success =
                                if (currentMode == "classic") {
                                    classicGamepadService.setBluetoothName(name)
                                } else {
                                    bleGamepadService.setBluetoothName(name)
                                }
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "Name cannot be null", null)
                    }
                }
                "getBluetoothName" -> {
                    val name =
                            if (currentMode == "classic") {
                                classicGamepadService.getBluetoothName()
                            } else {
                                bleGamepadService.getBluetoothName()
                            }
                    result.success(name)
                }
                "requestDiscoverable" -> {
                    val duration = call.argument<Int>("duration") ?: 300
                    Log.d(TAG, "requestDiscoverable called with duration: $duration")
                    try {
                        // For BLE mode, we don't need system discoverable - advertising handles it
                        if (currentMode == "ble") {
                            Log.d(
                                    TAG,
                                    "BLE mode: Already advertising, no need for system discoverable"
                            )
                            result.success(true)
                        } else {
                            val discoverableIntent =
                                    Intent(BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE).apply {
                                        putExtra(
                                                BluetoothAdapter.EXTRA_DISCOVERABLE_DURATION,
                                                duration
                                        )
                                    }
                            startActivity(discoverableIntent)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error requesting discoverability", e)
                        result.error("FLUTTER_ERROR", e.message, null)
                    }
                }
                else -> {
                    Log.w(TAG, "Unknown method call: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }

    private fun initialize(descriptor: ByteArray?, mode: String) {
        // Stop any existing service first
        if (isInitialized) {
            stop()
        }

        currentMode = mode
        Log.d(TAG, "Initializing with mode: $mode")

        when (mode) {
            "ble" -> {
                bleGamepadService.initialize(descriptor)
            }
            else -> {
                classicGamepadService.initialize(descriptor)
            }
        }
        isInitialized = true
    }

    private fun setMode(mode: String) {
        if (mode == currentMode) return

        Log.d(TAG, "Switching mode from $currentMode to $mode")
        // We don't auto-restart here, just store the preference
        currentMode = mode
    }

    private var mainReportCount = 0

    private fun sendRawReport(report: ByteArray) {
        if (mainReportCount++ % 100 == 0) {
            Log.d(TAG, "sendRawReport: currentMode=$currentMode, reportSize=${report.size}")
        }
        when (currentMode) {
            "ble" -> bleGamepadService.sendRawReport(report)
            else -> classicGamepadService.sendRawReport(report)
        }
    }

    private fun stop() {
        Log.d(TAG, "Stopping all services")
        classicGamepadService.stop()
        bleGamepadService.stop()
        isInitialized = false
    }

    // GamepadService.GamepadServiceListener callbacks
    override fun onConnectionStateChanged(deviceAddr: String, state: Int) {
        runOnUiThread {
            methodChannel?.invokeMethod(
                    "onConnectionStateChanged",
                    mapOf("address" to deviceAddr, "state" to state)
            )
        }
    }

    override fun onAppStatusChanged(registered: Boolean) {
        runOnUiThread {
            methodChannel?.invokeMethod("onAppStatusChanged", mapOf("registered" to registered))
        }
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume called")
        // When screen turns back on, verify the gamepad service state
        // This helps recover from screen off/on cycles
        if (currentMode == "classic" && isInitialized) {
            classicGamepadService.checkAndRestoreState()
        }
    }

    override fun onPause() {
        super.onPause()
        Log.d(TAG, "onPause called")
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy called")
        stop()
        super.onDestroy()
    }
}
