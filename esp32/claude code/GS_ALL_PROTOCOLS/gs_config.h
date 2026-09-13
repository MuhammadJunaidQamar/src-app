/*
  gs_config.h — every user-tunable knob for the APEXech Ground Station gateway.

  This is the ONLY file you normally edit. Nothing here changes the wire
  protocol the Flutter app speaks; the protocol constants that MUST NOT change
  are marked "PROTOCOL - DO NOT CHANGE".
*/

#ifndef GS_CONFIG_H
#define GS_CONFIG_H

// ============================================================
// TRANSPORT SELECTION
// ============================================================
// All transports can run at the same time. Flash once, then pick the mode in
// the Flutter app. Turn a transport off only to save RAM/flash.
//
//   Flutter "Bluetooth ground station"   -> GS_ENABLE_BLE
//   Flutter "Wi-Fi ground station"       -> GS_ENABLE_SOFTAP
//   Flutter "Router (LAN) ground station"-> GS_ENABLE_STA
//   Flutter "Broadcast / server"         -> GS_ENABLE_SERIAL_BINARY (USB)

#ifndef GS_ENABLE_BLE
#define GS_ENABLE_BLE 1
#endif

#ifndef GS_ENABLE_SOFTAP
#define GS_ENABLE_SOFTAP 1
#endif

#ifndef GS_ENABLE_STA
#define GS_ENABLE_STA 1
#endif

#ifndef GS_ENABLE_ESPNOW
#define GS_ENABLE_ESPNOW 1
#endif

// Relay ESP32-CAM frames: MJPEG on :81 (Wi-Fi) and chunked BLE notifies.
// Costs ~40 KB RAM. Set to 0 for a telemetry-only build.
#ifndef GS_ENABLE_CAMERA
#define GS_ENABLE_CAMERA 1
#endif

// Raw legacy binary telemetry on USB Serial (MATLAB / Python serial_reader).
// This is byte-for-byte what the original Ground_Station_Code.ino emitted.
#ifndef GS_ENABLE_SERIAL_BINARY
#define GS_ENABLE_SERIAL_BINARY 1
#endif

// Newline-delimited JSON on USB Serial, identical to the Wi-Fi/BLE payload.
// Easier to bridge than the binary struct. Mutually usable with the binary
// output only if your PC-side reader can tell them apart -- normally pick one.
#ifndef GS_ENABLE_SERIAL_JSON
#define GS_ENABLE_SERIAL_JSON 0
#endif

// Human-readable field dump once per second (debugging).
//
// NOTE: this text shares the UART with the binary/JSON telemetry above, so a
// PC-side parser sees them interleaved. The original firmware behaved the same
// way and readers cope by resyncing on the packet header — but for a clean
// broadcast-mode stream, set this (and GS_STATUS_INTERVAL_MS's block) to 0.
#ifndef GS_ENABLE_SERIAL_PRETTY
#define GS_ENABLE_SERIAL_PRETTY 1
#endif

// 0 = suppress the periodic status block too (fully clean binary/JSON stream).
#ifndef GS_ENABLE_SERIAL_STATUS
#define GS_ENABLE_SERIAL_STATUS 1
#endif

// ============================================================
// WI-FI
// ============================================================

// PROTOCOL - the Flutter pairing screen tells the user to join this SSID and
// hard-codes 192.168.4.1 for telemetry/camera in Wi-Fi mode.
#define GS_AP_SSID     "CanSat-GS"
#define GS_AP_PASSWORD "cansat123"   // >= 8 chars, or "" for an open AP
#define GS_AP_CHANNEL  1
#define GS_AP_MAX_CLIENTS 4

// Router (LAN) mode: your home/campus Wi-Fi. Leave GS_STA_SSID empty to skip.
#define GS_STA_SSID     ""
#define GS_STA_PASSWORD ""
#define GS_STA_CONNECT_TIMEOUT_MS 15000UL
#define GS_STA_RETRY_INTERVAL_MS  20000UL

// ============================================================
// PORTS  (PROTOCOL - DO NOT CHANGE)
// ============================================================
#define GS_HTTP_PORT      80     // /pair, /health, /telemetry, /discover
#define GS_WS_PORT        8765   // telemetry WebSocket
#define GS_CAM_PORT       81     // MJPEG /stream
#define GS_DISCOVERY_PORT 4210   // UDP "CANSATGS|<ip>" beacon

#define GS_DISCOVERY_INTERVAL_MS 2000UL

// ============================================================
// BLE  (PROTOCOL - DO NOT CHANGE)
// ============================================================
// The app scans for a name containing "CanSat" and reconnects with the exact
// name "CanSat-GS", so this string is part of the contract.
#define GS_BLE_NAME "CanSat-GS"

// Nordic UART Service: the app subscribes to TX and writes "PAIR:<code>" to RX.
#define GS_BLE_NUS_SERVICE_UUID "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define GS_BLE_NUS_TX_UUID      "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
#define GS_BLE_NUS_RX_UUID      "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"

// Camera notify service (6-byte big-endian header + JPEG slice per notify).
#define GS_BLE_CAM_SERVICE_UUID "6E400010-B5A3-F393-E0A9-E50E24DCCA9E"
#define GS_BLE_CAM_TX_UUID      "6E400011-B5A3-F393-E0A9-E50E24DCCA9E"

#define GS_BLE_MTU         517   // app requests 512; 517 = 3 ATT + 514 payload
#define GS_BLE_TX_POWER    9
#define GS_BLE_CAM_PAYLOAD 244   // 6 header + 244 = 250 <= MTU-3

// ============================================================
// PAIRING
// ============================================================
// 0 = accept any client without a code (bench testing only).
#ifndef GS_REQUIRE_PAIRING
#define GS_REQUIRE_PAIRING 1
#endif

// Pin the code instead of randomising at boot, e.g. "123456". Empty = random.
#define GS_FIXED_PAIR_CODE ""

// 1 = new code after a paired client leaves. 0 = same code until reboot
// (friendlier: Windows BLE drops the link mid-handshake fairly often).
#ifndef GS_ROTATE_PAIR_CODE
#define GS_ROTATE_PAIR_CODE 0
#endif

// ============================================================
// RATES / BUFFERS
// ============================================================
#define GS_TELEM_MIN_INTERVAL_MS 50UL    // 20 Hz cap on BLE/WS telemetry
#define GS_STATUS_INTERVAL_MS    5000UL  // Serial status block
#define GS_JSON_BUF_SIZE         640     // one telemetry payload, snprintf'd

#define GS_CAM_MAX_FRAME        20000    // largest JPEG we reassemble
#define GS_CAM_MAX_PACKETS      160      // 160 * 180 B = 28.8 kB ceiling
#define GS_CAM_MAX_HTTP_CLIENTS 3        // simultaneous MJPEG viewers

#endif // GS_CONFIG_H
