/*
  ===========================================================================
  CanSat / APEXech Ground Station — all Flutter transports in one firmware
  ===========================================================================

  ESP-NOW in  ->  BLE GATT + Wi-Fi SoftAP + Wi-Fi router (STA) + WebSocket
                  + HTTP + UDP discovery + MJPEG camera + USB Serial

  Flash this once and every connection mode in the Flutter app works; the app
  decides at runtime which transport to use. Individual transports can be
  compiled out in gs_config.h.

    Flutter mode                       transport used here
    ---------------------------------  -------------------------------------
    Bluetooth ground station           BLE GATT (NUS + camera service)
    Wi-Fi ground station               SoftAP "CanSat-GS" -> ws://192.168.4.1:8765
    Router (LAN) ground station        STA + UDP beacon -> ws://<lan-ip>:8765
    Broadcast / server                 USB Serial -> Python relay -> app
    Simulation                         (no hardware)

  Ports:  HTTP 80 | WebSocket 8765 | MJPEG 81 | UDP discovery 4210

  Libraries (Arduino IDE -> Library Manager):
    - NimBLE-Arduino            (h2zero)
    - WebSockets                (Markus Sattler)
  WiFi / WebServer / WiFiUdp / ESP-NOW ship with the ESP32 core.

  Board settings:
    Tools -> Partition Scheme -> "Huge APP (3MB No OTA)"  (BLE + Wi-Fi + camera
    does not fit the default partition)
    Serial Monitor -> 115200 baud

  Setup checklist:
    1. Boot once and read the Serial monitor: it prints the AP MAC and the
       STA MAC. Put the matching MAC in CANSAT.ino (broadcastAddress) and in
       Tx_camera_code.ino (receiverMAC).
         - SoftAP-only station  -> use the AP MAC
         - Router (STA) station -> use the STA MAC
    2. Note the 6-digit PAIRING CODE, enter it in the app.
    3. For router mode, fill in GS_STA_SSID / GS_STA_PASSWORD in gs_config.h.

  This is a rewrite of Ground_Station_Code.ino. The telemetry pipeline and the
  ESP-NOW packet layout are unchanged; what changed is everything the Flutter
  app parses — see PROTOCOL.md for the field-by-field contract and README.md
  for the list of fixes.
  ===========================================================================
*/

#include <esp_mac.h>
#include <esp_now.h>
#include <esp_wifi.h>

#include "gs_config.h"
#include "gs_telemetry.h"
#include "gs_camera.h"
#include "gs_net.h"
#include "gs_ble.h"

// ============================================================
// ESP-NOW RECEIVE
// ============================================================
// Runs on the Wi-Fi task. Rule: copy bytes, flip flags, return. No Serial, no
// String, no BLE calls here — those are what turn a working ground station
// into a random-reboot machine.

void gsOnEspNowRecv(const esp_now_recv_info_t *info,
                    const uint8_t *incomingData,
                    int len) {
#if GS_ENABLE_CAMERA
  if (len == GS_CAM_PACKET_LEN) {
    GsCamPacket p;
    memcpy(&p, incomingData, sizeof(p));
    gsCamOnPacket(p);
    return;
  }
#endif

  struct_message incoming;
  bool wasLegacy = false;

  if (len == (int)sizeof(struct_message)) {
    memcpy(&incoming, incomingData, sizeof(incoming));
  } else if (len == (int)sizeof(legacy_struct_message)) {
    legacy_struct_message leg;
    memcpy(&leg, incomingData, sizeof(leg));
    gsImportLegacy(leg, incoming);
    wasLegacy = true;
  } else {
    gsErrorCount++;
    return;
  }

  gsEnsureOrientation(incoming);
  gsSanitize(incoming);

  portENTER_CRITICAL(&gsTelemMux);
  gsTelem = incoming;
  gsHasTelemetry = true;
  gsTelemetryDirty = true;
  gsPacketCount++;
  gsLastTelemMs = millis();
  gsLastWasLegacy = wasLegacy;
  if (info != nullptr) {
    memcpy(gsLastSrcMac, info->src_addr, 6);
    gsSrcMacValid = true;
  }
  portEXIT_CRITICAL(&gsTelemMux);
}

static void gsEspNowSetup() {
#if GS_ENABLE_ESPNOW
  if (esp_now_init() != ESP_OK) {
    Serial.println("[ESP-NOW] ERROR: init failed");
    return;
  }
  esp_now_register_recv_cb(gsOnEspNowRecv);
  Serial.printf("[ESP-NOW] receiver ready (telemetry %u/%u B, camera %u B)\n",
                (unsigned)sizeof(legacy_struct_message),
                (unsigned)sizeof(struct_message),
                (unsigned)GS_CAM_PACKET_LEN);
#else
  Serial.println("[ESP-NOW] disabled in gs_config.h");
#endif
}

// ============================================================
// USB SERIAL OUTPUT (Broadcast / server mode)
// ============================================================

static char gsSerialJsonBuf[GS_JSON_BUF_SIZE];

static void gsServiceSerialOutput() {
  if (!gsTelemetryDirty) return;

  struct_message snapshot;
  if (!gsCopyTelemetry(snapshot)) {
    gsTelemetryDirty = false;
    return;
  }
  gsTelemetryDirty = false;

#if GS_ENABLE_SERIAL_BINARY
  // Byte-for-byte the packet the original firmware wrote, so the existing
  // MATLAB / Python serial readers keep working unchanged. Written from
  // loop(), never from the ESP-NOW callback.
  legacy_struct_message legacyOut;
  gsExportLegacy(snapshot, legacyOut);
  Serial.write((const uint8_t *)&legacyOut, sizeof(legacyOut));
#endif

#if GS_ENABLE_SERIAL_JSON
  // One JSON object per line — identical payload to Wi-Fi/BLE, so a PC-side
  // relay can forward the line straight into the app's WebSocket.
  const size_t n = gsBuildTelemetryJson(snapshot, gsSerialJsonBuf,
                                        sizeof(gsSerialJsonBuf));
  if (n > 0) {
    Serial.write((const uint8_t *)gsSerialJsonBuf, n);
    Serial.write('\n');
  }
#else
  (void)gsSerialJsonBuf;
#endif

#if GS_ENABLE_SERIAL_PRETTY
  static uint32_t lastPrettyMs = 0;
  const uint32_t now = millis();
  if (now - lastPrettyMs >= 1000) {
    lastPrettyMs = now;
    gsPrintTelemetry(snapshot, gsLastWasLegacy ? "legacy-CANSAT" : "extended");
  }
#endif
}

// ============================================================
// STATUS BLOCK
// ============================================================

static void gsPrintStatus() {
#if !GS_ENABLE_SERIAL_STATUS
  return;
#else
  static uint32_t lastMs = 0;
  const uint32_t now = millis();
  if (now - lastMs < GS_STATUS_INTERVAL_MS) return;
  lastMs = now;

  char mac[18] = "--:--:--:--:--:--";
  if (gsSrcMacValid) gsMacToStr(gsLastSrcMac, mac, sizeof(mac));

  Serial.println();
  Serial.println("========== CanSat GROUND STATION ==========");
  Serial.printf("PAIRING CODE : %s   %s\n", gsPairCode,
                gsPaired ? "(a client is paired)" : "(enter this in the app)");
  Serial.printf("ESP-NOW      : %lu packets, %lu bad-length, last from %s\n",
                (unsigned long)gsPacketCount, (unsigned long)gsErrorCount, mac);
  Serial.printf("Telemetry    : %s", gsHasTelemetry ? "AVAILABLE" : "WAITING");
  if (gsHasTelemetry) {
    Serial.printf(" (%lu ms ago)", (unsigned long)(now - gsLastTelemMs));
  }
  Serial.println();
#if GS_ENABLE_CAMERA
  Serial.printf("Camera       : %lu frames reassembled\n",
                (unsigned long)gsCamFramesIn);
#endif
#if GS_ENABLE_BLE
  Serial.printf("BLE          : %s as \"%s\"\n",
                gsBleConnected ? "CONNECTED" : "advertising", GS_BLE_NAME);
#endif
#if GS_ENABLE_SOFTAP
  Serial.printf("SoftAP       : %s  ws://%s:%u  http://%s:%u/stream\n",
                WiFi.softAPIP().toString().c_str(),
                WiFi.softAPIP().toString().c_str(), (unsigned)GS_WS_PORT,
                WiFi.softAPIP().toString().c_str(), (unsigned)GS_CAM_PORT);
  Serial.printf("AP clients   : %d\n", WiFi.softAPgetStationNum());
#endif
  if (gsStaConnected) {
    Serial.printf("Router (STA) : %s  ws://%s:%u\n",
                  WiFi.localIP().toString().c_str(),
                  WiFi.localIP().toString().c_str(), (unsigned)GS_WS_PORT);
  }
  Serial.printf("WS clients   : %d\n", gsWs.connectedClients());
  Serial.printf("Wi-Fi channel: %d      free heap: %lu B\n",
                WiFi.channel(), (unsigned long)ESP.getFreeHeap());
  Serial.println("===========================================");
#endif
}

static void gsPrintBootCard() {
  uint8_t apMac[6] = {0};
  uint8_t staMac[6] = {0};
  esp_read_mac(apMac, ESP_MAC_WIFI_SOFTAP);
  esp_read_mac(staMac, ESP_MAC_WIFI_STA);

  char apStr[18];
  char staStr[18];
  gsMacToStr(apMac, apStr, sizeof(apStr));
  gsMacToStr(staMac, staStr, sizeof(staStr));

  Serial.println();
  Serial.println("=============== PEER MAC ADDRESSES ===============");
  Serial.printf("AP  MAC : %s\n", apStr);
  Serial.printf("STA MAC : %s\n", staStr);
  Serial.println("Put ONE of these in CANSAT.ino broadcastAddress and in");
  Serial.println("Tx_camera_code.ino receiverMAC:");
  Serial.println("  SoftAP-only station  -> AP MAC");
  Serial.println("  Router (STA) station -> STA MAC");
  Serial.println("==================================================");
}

// ============================================================
// SETUP / LOOP
// ============================================================

void setup() {
  Serial.begin(115200);
  delay(400);

  Serial.println();
  Serial.println("==================================================");
  Serial.println("   CanSat Ground Station — all Flutter transports");
  Serial.println("   BLE + SoftAP + Router + WebSocket + HTTP + UDP");
  Serial.println("==================================================");

  // Wi-Fi must be up before ESP-NOW: ESP-NOW rides the active radio channel.
  gsWifiSetup();
  gsPrintBootCard();

  gsEspNowSetup();
  gsNetSetup();
  gsCamBegin();

#if GS_ENABLE_BLE
  gsBleSetup();
#endif

  gsGeneratePairCode();

  Serial.println("Services:");
#if GS_ENABLE_BLE
  Serial.println("  BLE GATT      -> " GS_BLE_NAME);
#endif
  Serial.printf("  HTTP          -> :%u  (/pair /health /telemetry /discover)\n",
                (unsigned)GS_HTTP_PORT);
  Serial.printf("  WebSocket     -> :%u\n", (unsigned)GS_WS_PORT);
#if GS_ENABLE_CAMERA
  Serial.printf("  MJPEG         -> :%u/stream\n", (unsigned)GS_CAM_PORT);
#endif
  Serial.printf("  UDP discovery -> :%u  (CANSATGS|<ip>)\n",
                (unsigned)GS_DISCOVERY_PORT);
#if !GS_REQUIRE_PAIRING
  Serial.println("  WARNING: GS_REQUIRE_PAIRING=0 — any client is accepted.");
#endif
  Serial.println();
}

void loop() {
  // Network servers.
  gsHttp.handleClient();
  gsWs.loop();

  // Camera relay.
  gsCamAcceptClients(gsPaired);
  if (gsPaired) {
    gsCamPushFrame();
  } else {
    gsCamDropClients();
  }

  // Telemetry fan-out.
  gsWsPushTelemetry();
  gsBlePushTelemetry();
  gsBlePushCameraFrame();

  // USB Serial (broadcast mode) — also clears gsTelemetryDirty.
  gsServiceSerialOutput();

  // UDP discovery beacon for router mode.
  static uint32_t lastDiscovery = 0;
  const uint32_t now = millis();
  if (now - lastDiscovery >= GS_DISCOVERY_INTERVAL_MS) {
    lastDiscovery = now;
    gsBroadcastDiscovery();
  }

  gsWifiMaintain();
  gsBleEnsureAdvertising();
  gsPrintStatus();

  delay(2);
}
