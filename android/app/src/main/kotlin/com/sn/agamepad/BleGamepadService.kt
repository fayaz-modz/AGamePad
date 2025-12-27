package com.sn.agamepad

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.ParcelUuid
import android.util.Log
import java.util.UUID

/**
 * BLE HID Gamepad Service - Uses HID over GATT Profile (HOGP)
 *
 * This version implements proper BLE security with pairing/bonding. Fire TV and similar devices
 * require bonded connections for HID input.
 */
class BleGamepadService(private val context: Context) {
  private val TAG = "BleGamepadService"

  companion object {
    // Generic Access Service (required for proper device identification)
    val GENERIC_ACCESS_SERVICE_UUID: UUID = UUID.fromString("00001800-0000-1000-8000-00805f9b34fb")
    val DEVICE_NAME_UUID: UUID = UUID.fromString("00002a00-0000-1000-8000-00805f9b34fb")
    val APPEARANCE_UUID: UUID = UUID.fromString("00002a01-0000-1000-8000-00805f9b34fb")

    // HID Service UUID
    val HID_SERVICE_UUID: UUID = UUID.fromString("00001812-0000-1000-8000-00805f9b34fb")
    val HID_INFORMATION_UUID: UUID = UUID.fromString("00002a4a-0000-1000-8000-00805f9b34fb")
    val HID_REPORT_MAP_UUID: UUID = UUID.fromString("00002a4b-0000-1000-8000-00805f9b34fb")
    val HID_CONTROL_POINT_UUID: UUID = UUID.fromString("00002a4c-0000-1000-8000-00805f9b34fb")
    val HID_REPORT_UUID: UUID = UUID.fromString("00002a4d-0000-1000-8000-00805f9b34fb")
    val PROTOCOL_MODE_UUID: UUID = UUID.fromString("00002a4e-0000-1000-8000-00805f9b34fb")

    // Descriptors
    val CCC_DESCRIPTOR_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    val REPORT_REFERENCE_UUID: UUID = UUID.fromString("00002908-0000-1000-8000-00805f9b34fb")

    // Device Information Service
    val DEVICE_INFO_SERVICE_UUID: UUID = UUID.fromString("0000180a-0000-1000-8000-00805f9b34fb")
    val MANUFACTURER_NAME_UUID: UUID = UUID.fromString("00002a29-0000-1000-8000-00805f9b34fb")
    val MODEL_NUMBER_UUID: UUID = UUID.fromString("00002a24-0000-1000-8000-00805f9b34fb")
    val PNP_ID_UUID: UUID = UUID.fromString("00002a50-0000-1000-8000-00805f9b34fb")

    // Battery Service
    val BATTERY_SERVICE_UUID: UUID = UUID.fromString("0000180f-0000-1000-8000-00805f9b34fb")
    val BATTERY_LEVEL_UUID: UUID = UUID.fromString("00002a19-0000-1000-8000-00805f9b34fb")

    // Appearance value for Gamepad (0x03C4 = 964)
    const val APPEARANCE_GAMEPAD = 0x03C4
  }

  private var bluetoothManager: BluetoothManager? = null
  private var bluetoothAdapter: BluetoothAdapter? = null
  private var bluetoothLeAdvertiser: BluetoothLeAdvertiser? = null
  private var gattServer: BluetoothGattServer? = null

  private var reportCharacteristic: BluetoothGattCharacteristic? = null
  private var connectedDevice: BluetoothDevice? = null
  private var notificationsEnabled = false

  private var reportDescriptor: ByteArray? = null
  private var isAdvertising = false
  private var isBonded = false

  var listener: BleGamepadServiceListener? = null

  interface BleGamepadServiceListener {
    fun onConnectionStateChanged(deviceAddr: String, state: Int)
    fun onAppStatusChanged(registered: Boolean)
  }

  // Broadcast receiver for bonding state changes
  private val bondStateReceiver =
          object : BroadcastReceiver() {
            @SuppressLint("MissingPermission")
            override fun onReceive(context: Context?, intent: Intent?) {
              if (intent?.action == BluetoothDevice.ACTION_BOND_STATE_CHANGED) {
                val device =
                        intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                val bondState =
                        intent.getIntExtra(
                                BluetoothDevice.EXTRA_BOND_STATE,
                                BluetoothDevice.BOND_NONE
                        )
                val previousState =
                        intent.getIntExtra(
                                BluetoothDevice.EXTRA_PREVIOUS_BOND_STATE,
                                BluetoothDevice.BOND_NONE
                        )

                Log.d(
                        TAG,
                        "Bond state changed: ${device?.address} from ${getBondStateString(previousState)} to ${getBondStateString(bondState)}"
                )

                when (bondState) {
                  BluetoothDevice.BOND_BONDED -> {
                    Log.d(TAG, "Device bonded successfully: ${device?.address}")
                    isBonded = true
                    // Notify that device is now properly connected and bonded
                    device?.let { listener?.onConnectionStateChanged(it.address, 2) }
                  }
                  BluetoothDevice.BOND_NONE -> {
                    if (previousState == BluetoothDevice.BOND_BONDING) {
                      Log.w(TAG, "Bonding failed for device: ${device?.address}")
                      isBonded = false
                    }
                  }
                  BluetoothDevice.BOND_BONDING -> {
                    Log.d(TAG, "Bonding in progress for device: ${device?.address}")
                  }
                }
              }
            }
          }

  private fun getBondStateString(state: Int): String {
    return when (state) {
      BluetoothDevice.BOND_NONE -> "BOND_NONE"
      BluetoothDevice.BOND_BONDING -> "BOND_BONDING"
      BluetoothDevice.BOND_BONDED -> "BOND_BONDED"
      else -> "UNKNOWN($state)"
    }
  }

  private val gattServerCallback =
          object : BluetoothGattServerCallback() {
            @SuppressLint("MissingPermission")
            override fun onConnectionStateChange(
                    device: BluetoothDevice?,
                    status: Int,
                    newState: Int
            ) {
              Log.d(
                      TAG,
                      "onConnectionStateChange: device=${device?.address}, status=$status, newState=$newState, bondState=${device?.bondState?.let { getBondStateString(it) }}"
              )

              when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                  connectedDevice = device
                  Log.d(TAG, "Device connected: ${device?.address}")

                  // Check if already bonded
                  if (device?.bondState == BluetoothDevice.BOND_BONDED) {
                    Log.d(TAG, "Device is already bonded")
                    isBonded = true
                    device.let { listener?.onConnectionStateChanged(it.address, 2) }
                  } else {
                    // Need to initiate bonding
                    Log.d(TAG, "Device not bonded, initiating pairing...")
                    isBonded = false
                    // The bonding will be triggered when the device tries to read encrypted
                    // characteristics
                    // We still notify connection, but the device will trigger pairing
                    device?.let {
                      listener?.onConnectionStateChanged(it.address, 1)
                    } // 1 = Connecting/Pairing
                  }
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                  if (device?.address == connectedDevice?.address) {
                    connectedDevice = null
                    notificationsEnabled = false
                    isBonded = false
                  }
                  Log.d(TAG, "Device disconnected: ${device?.address}, status=$status")
                  logDisconnectReason(status)
                  device?.let { listener?.onConnectionStateChanged(it.address, 0) }
                }
              }
            }

            private fun logDisconnectReason(status: Int) {
              when (status) {
                0 -> Log.d(TAG, "Disconnection: Success/Normal")
                8 -> Log.w(TAG, "Disconnection: Connection timeout")
                19 -> Log.w(TAG, "Disconnection: Remote device terminated connection")
                22 -> Log.w(TAG, "Disconnection: Local host terminated connection")
                34 -> Log.w(TAG, "Disconnection: LMP response timeout")
                62 -> Log.w(TAG, "Disconnection: Connection failed to establish")
                133 -> Log.w(TAG, "Disconnection: GATT error (security/pairing issue)")
                else -> Log.w(TAG, "Disconnection: Unknown status $status")
              }
            }

            @SuppressLint("MissingPermission")
            override fun onCharacteristicReadRequest(
                    device: BluetoothDevice?,
                    requestId: Int,
                    offset: Int,
                    characteristic: BluetoothGattCharacteristic?
            ) {
              Log.d(
                      TAG,
                      "onCharacteristicReadRequest: ${characteristic?.uuid}, offset=$offset, from=${device?.address}"
              )

              val response =
                      when (characteristic?.uuid) {
                        // Generic Access
                        DEVICE_NAME_UUID -> {
                          "AGamepad".toByteArray(Charsets.UTF_8)
                        }
                        APPEARANCE_UUID -> {
                          // Gamepad appearance (0x03C4) as little-endian
                          byteArrayOf(
                                  (APPEARANCE_GAMEPAD and 0xFF).toByte(),
                                  ((APPEARANCE_GAMEPAD shr 8) and 0xFF).toByte()
                          )
                        }
                        // HID Service
                        HID_INFORMATION_UUID -> {
                          // HID Information: bcdHID (1.11), bCountryCode (0), Flags (remote wake +
                          // normally connectable)
                          byteArrayOf(0x11, 0x01, 0x00, 0x03)
                        }
                        HID_REPORT_MAP_UUID -> {
                          Log.d(
                                  TAG,
                                  "Sending HID Report Map (descriptor), size=${reportDescriptor?.size ?: 0}"
                          )
                          reportDescriptor ?: byteArrayOf()
                        }
                        PROTOCOL_MODE_UUID -> {
                          // Report Protocol Mode (1)
                          byteArrayOf(0x01)
                        }
                        HID_REPORT_UUID -> {
                          // Return neutral gamepad state with Report ID
                          byteArrayOf(0x01, 127, 127, 127, 127, 0, 0, 8)
                        }
                        // Device Information
                        MANUFACTURER_NAME_UUID -> {
                          "AGamepad".toByteArray(Charsets.UTF_8)
                        }
                        MODEL_NUMBER_UUID -> {
                          "BLE Gamepad".toByteArray(Charsets.UTF_8)
                        }
                        PNP_ID_UUID -> {
                          // PnP ID: Vendor ID Source (USB=2), Vendor ID (0x046D Logitech for
                          // compatibility), Product ID, Version
                          byteArrayOf(0x02, 0x6D.toByte(), 0x04, 0x00, 0x00, 0x01, 0x00)
                        }
                        // Battery
                        BATTERY_LEVEL_UUID -> {
                          byteArrayOf(100.toByte())
                        }
                        else -> {
                          Log.w(TAG, "Unknown characteristic read: ${characteristic?.uuid}")
                          null
                        }
                      }

              if (response != null) {
                val responseData =
                        if (offset < response.size) {
                          response.copyOfRange(offset, response.size)
                        } else {
                          byteArrayOf()
                        }
                gattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_SUCCESS,
                        offset,
                        responseData
                )
              } else {
                gattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_READ_NOT_PERMITTED,
                        0,
                        null
                )
              }
            }

            @SuppressLint("MissingPermission")
            override fun onDescriptorReadRequest(
                    device: BluetoothDevice?,
                    requestId: Int,
                    offset: Int,
                    descriptor: BluetoothGattDescriptor?
            ) {
              Log.d(TAG, "onDescriptorReadRequest: ${descriptor?.uuid}")

              when (descriptor?.uuid) {
                CCC_DESCRIPTOR_UUID -> {
                  val value =
                          if (notificationsEnabled) {
                            BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                          } else {
                            BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE
                          }
                  gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, value)
                }
                REPORT_REFERENCE_UUID -> {
                  // Report ID (0 for single report) and Report Type (Input = 1)
                  gattServer?.sendResponse(
                          device,
                          requestId,
                          BluetoothGatt.GATT_SUCCESS,
                          0,
                          byteArrayOf(0x00, 0x01)
                  )
                }
                else -> {
                  gattServer?.sendResponse(
                          device,
                          requestId,
                          BluetoothGatt.GATT_SUCCESS,
                          0,
                          descriptor?.value ?: byteArrayOf()
                  )
                }
              }
            }

            @SuppressLint("MissingPermission")
            override fun onDescriptorWriteRequest(
                    device: BluetoothDevice?,
                    requestId: Int,
                    descriptor: BluetoothGattDescriptor?,
                    preparedWrite: Boolean,
                    responseNeeded: Boolean,
                    offset: Int,
                    value: ByteArray?
            ) {
              Log.d(
                      TAG,
                      "onDescriptorWriteRequest: ${descriptor?.uuid}, value=${value?.contentToString()}"
              )

              if (descriptor?.uuid == CCC_DESCRIPTOR_UUID) {
                notificationsEnabled =
                        value?.contentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE) ==
                                true
                Log.d(TAG, "Notifications enabled: $notificationsEnabled")

                if (notificationsEnabled && isBonded) {
                  // Now fully connected and ready for input
                  Log.d(TAG, "Device fully connected and ready for HID input")
                  device?.let { listener?.onConnectionStateChanged(it.address, 2) }
                }
              }

              if (responseNeeded) {
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
              }
            }

            @SuppressLint("MissingPermission")
            override fun onCharacteristicWriteRequest(
                    device: BluetoothDevice?,
                    requestId: Int,
                    characteristic: BluetoothGattCharacteristic?,
                    preparedWrite: Boolean,
                    responseNeeded: Boolean,
                    offset: Int,
                    value: ByteArray?
            ) {
              Log.d(TAG, "onCharacteristicWriteRequest: ${characteristic?.uuid}")

              if (characteristic?.uuid == HID_CONTROL_POINT_UUID) {
                val command = value?.getOrNull(0)?.toInt() ?: -1
                when (command) {
                  0 -> Log.d(TAG, "HID Control Point: Suspend")
                  1 -> Log.d(TAG, "HID Control Point: Exit Suspend")
                  else -> Log.d(TAG, "HID Control Point: Unknown command $command")
                }
              }

              if (responseNeeded) {
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
              }
            }

            override fun onMtuChanged(device: BluetoothDevice?, mtu: Int) {
              Log.d(TAG, "MTU changed to $mtu for device ${device?.address}")
            }
          }

  private val advertiseCallback =
          object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
              Log.d(TAG, "BLE advertising started successfully")
              isAdvertising = true
              listener?.onAppStatusChanged(true)
            }

            override fun onStartFailure(errorCode: Int) {
              val errorMsg =
                      when (errorCode) {
                        ADVERTISE_FAILED_ALREADY_STARTED -> "Already started"
                        ADVERTISE_FAILED_DATA_TOO_LARGE -> "Data too large"
                        ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "Feature unsupported"
                        ADVERTISE_FAILED_INTERNAL_ERROR -> "Internal error"
                        ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> "Too many advertisers"
                        else -> "Unknown error $errorCode"
                      }
              Log.e(TAG, "BLE advertising failed: $errorMsg")
              isAdvertising = false
              listener?.onAppStatusChanged(false)
            }
          }

  @SuppressLint("MissingPermission")
  fun initialize(descriptor: ByteArray?) {
    Log.d(TAG, "initialize() called with descriptor size: ${descriptor?.size ?: 0}")
    this.reportDescriptor = descriptor

    bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    bluetoothAdapter = bluetoothManager?.adapter

    if (bluetoothAdapter == null || !bluetoothAdapter!!.isEnabled) {
      Log.e(TAG, "Bluetooth is not available or not enabled")
      return
    }

    bluetoothLeAdvertiser = bluetoothAdapter?.bluetoothLeAdvertiser
    if (bluetoothLeAdvertiser == null) {
      Log.e(TAG, "BLE advertising is not supported on this device")
      return
    }

    // Register for bonding state changes
    val filter = IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
    context.registerReceiver(bondStateReceiver, filter)

    // Setup GATT Server
    setupGattServer()

    // Start advertising
    startAdvertising()
  }

  @SuppressLint("MissingPermission")
  private fun setupGattServer() {
    gattServer = bluetoothManager?.openGattServer(context, gattServerCallback)

    if (gattServer == null) {
      Log.e(TAG, "Failed to open GATT server")
      return
    }

    // 1. Add Generic Access Service (REQUIRED - this tells the device what we are)
    val genericAccessService =
            BluetoothGattService(
                    GENERIC_ACCESS_SERVICE_UUID,
                    BluetoothGattService.SERVICE_TYPE_PRIMARY
            )

    val deviceNameChar =
            BluetoothGattCharacteristic(
                    DEVICE_NAME_UUID,
                    BluetoothGattCharacteristic.PROPERTY_READ,
                    BluetoothGattCharacteristic.PERMISSION_READ
            )
    genericAccessService.addCharacteristic(deviceNameChar)

    val appearanceChar =
            BluetoothGattCharacteristic(
                    APPEARANCE_UUID,
                    BluetoothGattCharacteristic.PROPERTY_READ,
                    BluetoothGattCharacteristic.PERMISSION_READ
            )
    genericAccessService.addCharacteristic(appearanceChar)

    gattServer?.addService(genericAccessService)
    Log.d(TAG, "Generic Access Service added (Appearance: Gamepad 0x03C4)")

    // Small delay to ensure service is added before the next one
    Thread.sleep(100)

    // 2. Add HID Service with ENCRYPTED permissions (triggers pairing)
    val hidService =
            BluetoothGattService(HID_SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)

    // HID Information (encrypted read)
    val hidInfoChar =
            BluetoothGattCharacteristic(
                    HID_INFORMATION_UUID,
                    BluetoothGattCharacteristic.PROPERTY_READ,
                    BluetoothGattCharacteristic.PERMISSION_READ_ENCRYPTED
            )
    hidService.addCharacteristic(hidInfoChar)

    // Report Map (encrypted read)
    val reportMapChar =
            BluetoothGattCharacteristic(
                    HID_REPORT_MAP_UUID,
                    BluetoothGattCharacteristic.PROPERTY_READ,
                    BluetoothGattCharacteristic.PERMISSION_READ_ENCRYPTED
            )
    hidService.addCharacteristic(reportMapChar)

    // HID Control Point (encrypted write)
    val controlPointChar =
            BluetoothGattCharacteristic(
                    HID_CONTROL_POINT_UUID,
                    BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
                    BluetoothGattCharacteristic.PERMISSION_WRITE_ENCRYPTED
            )
    hidService.addCharacteristic(controlPointChar)

    // Protocol Mode (encrypted read/write)
    val protocolModeChar =
            BluetoothGattCharacteristic(
                    PROTOCOL_MODE_UUID,
                    BluetoothGattCharacteristic.PROPERTY_READ or
                            BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
                    BluetoothGattCharacteristic.PERMISSION_READ_ENCRYPTED or
                            BluetoothGattCharacteristic.PERMISSION_WRITE_ENCRYPTED
            )
    hidService.addCharacteristic(protocolModeChar)

    // HID Report (encrypted read/notify)
    reportCharacteristic =
            BluetoothGattCharacteristic(
                    HID_REPORT_UUID,
                    BluetoothGattCharacteristic.PROPERTY_READ or
                            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
                    BluetoothGattCharacteristic.PERMISSION_READ_ENCRYPTED
            )

    // CCC Descriptor (must be writable for notifications)
    val cccDescriptor =
            BluetoothGattDescriptor(
                    CCC_DESCRIPTOR_UUID,
                    BluetoothGattDescriptor.PERMISSION_READ or
                            BluetoothGattDescriptor.PERMISSION_WRITE
            )
    reportCharacteristic?.addDescriptor(cccDescriptor)

    // Report Reference Descriptor
    val reportRefDescriptor =
            BluetoothGattDescriptor(
                    REPORT_REFERENCE_UUID,
                    BluetoothGattDescriptor.PERMISSION_READ_ENCRYPTED
            )
    reportCharacteristic?.addDescriptor(reportRefDescriptor)

    hidService.addCharacteristic(reportCharacteristic)

    gattServer?.addService(hidService)
    Log.d(TAG, "HID Service added with encrypted permissions")

    Thread.sleep(100)

    // 3. Add Device Information Service
    val deviceInfoService =
            BluetoothGattService(
                    DEVICE_INFO_SERVICE_UUID,
                    BluetoothGattService.SERVICE_TYPE_PRIMARY
            )

    val manufacturerChar =
            BluetoothGattCharacteristic(
                    MANUFACTURER_NAME_UUID,
                    BluetoothGattCharacteristic.PROPERTY_READ,
                    BluetoothGattCharacteristic.PERMISSION_READ
            )
    deviceInfoService.addCharacteristic(manufacturerChar)

    val modelNumberChar =
            BluetoothGattCharacteristic(
                    MODEL_NUMBER_UUID,
                    BluetoothGattCharacteristic.PROPERTY_READ,
                    BluetoothGattCharacteristic.PERMISSION_READ
            )
    deviceInfoService.addCharacteristic(modelNumberChar)

    val pnpIdChar =
            BluetoothGattCharacteristic(
                    PNP_ID_UUID,
                    BluetoothGattCharacteristic.PROPERTY_READ,
                    BluetoothGattCharacteristic.PERMISSION_READ
            )
    deviceInfoService.addCharacteristic(pnpIdChar)

    gattServer?.addService(deviceInfoService)
    Log.d(TAG, "Device Information Service added")

    Thread.sleep(100)

    // 4. Add Battery Service
    val batteryService =
            BluetoothGattService(BATTERY_SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)

    val batteryLevelChar =
            BluetoothGattCharacteristic(
                    BATTERY_LEVEL_UUID,
                    BluetoothGattCharacteristic.PROPERTY_READ or
                            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
                    BluetoothGattCharacteristic.PERMISSION_READ
            )
    val batteryCccDescriptor =
            BluetoothGattDescriptor(
                    CCC_DESCRIPTOR_UUID,
                    BluetoothGattDescriptor.PERMISSION_READ or
                            BluetoothGattDescriptor.PERMISSION_WRITE
            )
    batteryLevelChar.addDescriptor(batteryCccDescriptor)
    batteryService.addCharacteristic(batteryLevelChar)

    gattServer?.addService(batteryService)
    Log.d(TAG, "Battery Service added")
  }

  @SuppressLint("MissingPermission")
  private fun startAdvertising() {
    val settings =
            AdvertiseSettings.Builder()
                    .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                    .setConnectable(true)
                    .setTimeout(0)
                    .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
                    .build()

    val advertiseData =
            AdvertiseData.Builder()
                    .setIncludeDeviceName(true)
                    .setIncludeTxPowerLevel(false)
                    .addServiceUuid(ParcelUuid(HID_SERVICE_UUID))
                    .build()

    val scanResponse =
            AdvertiseData.Builder()
                    .setIncludeDeviceName(false)
                    .addServiceUuid(ParcelUuid(DEVICE_INFO_SERVICE_UUID))
                    .build()

    Log.d(TAG, "Starting BLE advertising with HID service UUID...")
    bluetoothLeAdvertiser?.startAdvertising(
            settings,
            advertiseData,
            scanResponse,
            advertiseCallback
    )
  }

  @SuppressLint("MissingPermission")
  fun sendRawReport(report: ByteArray) {
    val device = connectedDevice ?: return
    val characteristic = reportCharacteristic ?: return

    if (!notificationsEnabled || !isBonded) return

    characteristic.value = report
    gattServer?.notifyCharacteristicChanged(device, characteristic, false)
  }

  @SuppressLint("MissingPermission")
  fun stop() {
    Log.d(TAG, "stop() called")

    try {
      context.unregisterReceiver(bondStateReceiver)
    } catch (e: Exception) {
      Log.w(TAG, "Receiver not registered: ${e.message}")
    }

    if (isAdvertising) {
      bluetoothLeAdvertiser?.stopAdvertising(advertiseCallback)
      isAdvertising = false
    }

    connectedDevice?.let { device -> gattServer?.cancelConnection(device) }
    gattServer?.close()
    gattServer = null

    connectedDevice = null
    notificationsEnabled = false
    isBonded = false

    listener?.onAppStatusChanged(false)
    Log.d(TAG, "BLE Gamepad Service stopped")
  }

  @SuppressLint("MissingPermission")
  fun getBluetoothName(): String {
    return bluetoothAdapter?.name ?: "Unknown"
  }

  @SuppressLint("MissingPermission")
  fun setBluetoothName(name: String): Boolean {
    return try {
      bluetoothAdapter?.setName(name) ?: false
    } catch (e: Exception) {
      Log.e(TAG, "Error setting Bluetooth name", e)
      false
    }
  }
}
