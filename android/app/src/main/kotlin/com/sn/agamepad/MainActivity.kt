package com.sn.agamepad

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), GamepadService.GamepadServiceListener {
    private val CHANNEL = "com.sn.agamepad/gamepad"
    private lateinit var gamepadService: GamepadService
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        gamepadService = GamepadService(this)
        gamepadService.listener = this
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        android.util.Log.d("MainActivity", "configureFlutterEngine called")
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            // Skip logging for high-frequency sendInput calls to avoid latency
            if (call.method != "sendInput") {
                android.util.Log.d("MainActivity", "Method call received: ${call.method}")
            }
            when (call.method) {
                "initialize" -> {
                    android.util.Log.d("MainActivity", "Calling gamepadService.initialize()")
                    val descriptor = call.argument<ByteArray>("descriptor")
                    gamepadService.initialize(descriptor)
                    result.success(null)
                }
                "sendInput" -> {
                    val buttons = call.argument<Int>("buttons") ?: 0
                    val lx = call.argument<Int>("lx") ?: 127
                    val ly = call.argument<Int>("ly") ?: 127
                    val rx = call.argument<Int>("rx") ?: 127
                    val ry = call.argument<Int>("ry") ?: 127
                    val dpad = call.argument<Int>("dpad") ?: 0
                    gamepadService.sendReport(buttons, lx, ly, rx, ry, dpad)
                    result.success(null)
                }
                "stop" -> {
                    android.util.Log.d("MainActivity", "Calling gamepadService.stop()")
                    gamepadService.stop()
                    result.success(null)
                }
                "getPairedDevices" -> {
                    android.util.Log.d("MainActivity", "Calling gamepadService.getPairedDevices()")
                    val devices = gamepadService.getPairedDevices()
                    android.util.Log.d(
                            "MainActivity",
                            "getPairedDevices returned ${devices.size} devices"
                    )
                    result.success(devices)
                }
                "connect" -> {
                    val address = call.argument<String>("address")
                    android.util.Log.d("MainActivity", "Connect called for address: $address")
                    if (address != null) {
                        gamepadService.connect(address)
                        result.success(null)
                    } else {
                        android.util.Log.e("MainActivity", "Connect: Address is null")
                        result.error("INVALID_ARGUMENT", "Address cannot be null", null)
                    }
                }
                "disconnect" -> {
                    val address = call.argument<String>("address")
                    android.util.Log.d("MainActivity", "Disconnect called for address: $address")
                    if (address != null) {
                        gamepadService.disconnect(address)
                        result.success(null)
                    } else {
                        android.util.Log.e("MainActivity", "Disconnect: Address is null")
                        result.error("INVALID_ARGUMENT", "Address cannot be null", null)
                    }
                }
                else -> {
                    android.util.Log.w("MainActivity", "Unknown method call: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }

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
        android.util.Log.d("MainActivity", "onResume called")
        // When screen turns back on, verify the gamepad service state
        // This helps recover from screen off/on cycles
        gamepadService.checkAndRestoreState()
    }

    override fun onPause() {
        super.onPause()
        android.util.Log.d("MainActivity", "onPause called")
    }

    override fun onDestroy() {
        android.util.Log.d("MainActivity", "onDestroy called")
        gamepadService.stop()
        super.onDestroy()
    }
}
