/*
  gs_net.h — Wi-Fi radio, HTTP :80, WebSocket :8765, UDP discovery :4210.

  Fixes vs the base Ground_Station_Code.ino
  -----------------------------------------
  1. SSID/IP        The app hard-codes ws://192.168.4.1:8765 and
                    http://192.168.4.1:81/stream and tells the user to join
                    "CanSat-GS". The base sketch published an AP named
                    "internet" and never called softAPConfig(), so the address
                    was whatever the core defaulted to.
  2. /pair          The base sketch ignored ?code= and returned a device
                    description. pairWifiWithCode() requires a body containing
                    "pair":"ok", so pairing always failed.
  3. UDP beacon     The base sketch broadcast JSON. discoverGroundStationHosts()
                    (lib/utils/connection/ground_station_discovery_io.dart)
                    only accepts plain text starting with "CANSATGS", so router
                    mode never found the station.
  4. Broadcast addr Only 255.255.255.255 was used; many routers drop it. The
                    subnet address (x.x.x.255) is now sent as well.
  5. CORS           Flutter Web calls /pair from a browser origin. Without
                    Access-Control-Allow-Origin the request is blocked before
                    it reaches the ESP32.
*/

#ifndef GS_NET_H
#define GS_NET_H

#include <WiFi.h>
#include <WiFiUdp.h>
#include <WebServer.h>
#include <WebSocketsServer.h>
#include <esp_wifi.h>

#include "gs_camera.h"
#include "gs_config.h"
#include "gs_telemetry.h"

WebServer         gsHttp(GS_HTTP_PORT);
WebSocketsServer  gsWs(GS_WS_PORT);
WiFiUDP           gsUdp;

static bool gsStaConnected = false;
static bool gsApStarted    = false;
static char gsNetJsonBuf[GS_JSON_BUF_SIZE];

static inline bool gsStaConfigured() {
  return GS_ENABLE_STA && sizeof(GS_STA_SSID) - 1 > 0;
}

// ============================================================
// HTTP helpers
// ============================================================

static void gsHttpCors() {
  gsHttp.sendHeader("Access-Control-Allow-Origin", "*");
  gsHttp.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  gsHttp.sendHeader("Access-Control-Allow-Headers", "Content-Type");
  gsHttp.sendHeader("Cache-Control", "no-store");
}

static void gsHttpSend(int code, const char *type, const String &body) {
  gsHttpCors();
  gsHttp.send(code, type, body);
}

static String gsLatestTelemetryJson() {
  struct_message snapshot;
  if (!gsCopyTelemetry(snapshot)) {
    return String("{\"status\":\"waiting_for_telemetry\"}");
  }
  const size_t n = gsBuildTelemetryJson(snapshot, gsNetJsonBuf, sizeof(gsNetJsonBuf));
  if (n == 0) return String("{\"status\":\"encode_error\"}");
  return String(gsNetJsonBuf);
}

// ============================================================
// HTTP handlers
// ============================================================

static void gsHandleRoot() {
  String html;
  html.reserve(1400);
  html += F("<!doctype html><html><head><meta name='viewport' "
            "content='width=device-width,initial-scale=1'>"
            "<title>CanSat Ground Station</title></head><body>"
            "<h1>CanSat Ground Station</h1><p>Status: ONLINE</p><ul>");
  html += "<li>WebSocket: ws://" + WiFi.softAPIP().toString() + ":" + String(GS_WS_PORT) + "</li>";
  html += "<li>MJPEG: http://" + WiFi.softAPIP().toString() + ":" + String(GS_CAM_PORT) + "/stream</li>";
  html += "<li>UDP discovery: " + String(GS_DISCOVERY_PORT) + "</li>";
  html += F("</ul><p><a href='/health'>/health</a> &middot; "
            "<a href='/telemetry'>/telemetry</a> &middot; "
            "<a href='/discover'>/discover</a></p>"
            "<p>Pair first: <code>/pair?code=NNNNNN</code> "
            "(6-digit code on the Serial monitor).</p></body></html>");
  gsHttpSend(200, "text/html", html);
}

static void gsHandleHealth() {
  String json;
  json.reserve(420);
  json += "{\"status\":\"ok\"";
  json += ",\"device\":\"" GS_BLE_NAME "\"";
  json += ",\"uptime_ms\":" + String(millis());
  json += ",\"hasTelemetry\":" + String(gsHasTelemetry ? "true" : "false");
  json += ",\"paired\":" + String(gsPaired ? "true" : "false");
  json += ",\"packets\":" + String(gsPacketCount);
  json += ",\"errors\":" + String(gsErrorCount);
  json += ",\"cameraFrames\":" + String((unsigned long)gsCamFramesIn);
  json += ",\"wsPort\":" + String(GS_WS_PORT);
  json += ",\"cameraPort\":" + String(GS_CAM_PORT);
  json += ",\"apIp\":\"" + WiFi.softAPIP().toString() + "\"";
  json += ",\"staIp\":\"" + (gsStaConnected ? WiFi.localIP().toString() : String("")) + "\"";
  json += ",\"channel\":" + String(WiFi.channel());
  json += ",\"heap\":" + String((unsigned long)ESP.getFreeHeap());
  json += "}";
  gsHttpSend(200, "application/json", json);
}

// pairWifiWithCode() only checks for the substring "pair":"ok", and treats any
// non-200 or a missing match as a wrong code, so both outcomes return 200.
static void gsHandlePair() {
  if (!gsHttp.hasArg("code")) {
    gsHttpSend(400, "application/json", F("{\"pair\":\"fail\",\"reason\":\"missing_code\"}"));
    return;
  }

  const String code = gsHttp.arg("code");
  if (gsCheckPairCode(code.c_str(), code.length())) {
    gsPaired = true;
    gsTelemetryDirty = true;
    Serial.printf("[PAIR] HTTP OK from %s\n", gsHttp.client().remoteIP().toString().c_str());
    gsHttpSend(200, "application/json", F("{\"pair\":\"ok\"}"));
  } else {
    Serial.println("[PAIR] HTTP FAIL — wrong code");
    gsHttpSend(200, "application/json", F("{\"pair\":\"fail\"}"));
  }
}

static void gsHandleTelemetry() {
  if (!gsPaired) {
    gsHttpSend(403, "application/json", F("{\"pair\":\"required\"}"));
    return;
  }
  gsHttpSend(200, "application/json", gsLatestTelemetryJson());
}

// Machine-readable pairing/endpoint card. Not required by the app; handy for
// desktop tooling and for Flutter Web, which cannot listen for UDP beacons.
static void gsHandleDiscover() {
  String json;
  json.reserve(360);
  json += "{\"device\":\"" GS_BLE_NAME "\",\"type\":\"ground_station\"";
  json += ",\"httpPort\":" + String(GS_HTTP_PORT);
  json += ",\"wsPort\":" + String(GS_WS_PORT);
  json += ",\"cameraPort\":" + String(GS_CAM_PORT);
  json += ",\"discoveryPort\":" + String(GS_DISCOVERY_PORT);
  json += ",\"bleName\":\"" GS_BLE_NAME "\"";
  json += ",\"apIp\":\"" + WiFi.softAPIP().toString() + "\"";
  json += ",\"staIp\":\"" + (gsStaConnected ? WiFi.localIP().toString() : String("")) + "\"";
  json += ",\"paired\":" + String(gsPaired ? "true" : "false");
  json += ",\"telemetry\":" + String(gsHasTelemetry ? "true" : "false");
  json += "}";
  gsHttpSend(200, "application/json", json);
}

static void gsHandleNotFound() {
  // Browsers send an OPTIONS preflight before the cross-origin /pair GET.
  if (gsHttp.method() == HTTP_OPTIONS) {
    gsHttpCors();
    gsHttp.send(204);
    return;
  }
  gsHttpSend(404, "application/json", F("{\"error\":\"not_found\"}"));
}

// ============================================================
// WebSocket
// ============================================================

static void gsWsEvent(uint8_t num, WStype_t type, uint8_t *payload, size_t length) {
  switch (type) {
    case WStype_CONNECTED: {
      Serial.printf("[WS] client %u connected from %s\n", num,
                    gsWs.remoteIP(num).toString().c_str());
      if (gsPaired) {
        // sendTXT takes String& (non-const), so the payload needs a name.
        String snapshot = gsLatestTelemetryJson();
        gsWs.sendTXT(num, snapshot);
      } else {
        // Deliberately NOT JSON. The app feeds every WebSocket frame straight
        // into Model.fromJson, and any JSON object it does not recognise
        // becomes an all-null Model that would blank the dashboard. Plain text
        // makes jsonDecode throw, which the app already catches and ignores,
        // while still telling other tooling why nothing is arriving.
        gsWs.sendTXT(num, "pair_required");
      }
      break;
    }

    case WStype_DISCONNECTED:
      Serial.printf("[WS] client %u disconnected\n", num);
      break;

    case WStype_TEXT: {
      if (length == 0) return;
      String msg;
      msg.reserve(length + 1);
      for (size_t i = 0; i < length; i++) msg += (char)payload[i];

      if (msg == "ping") {
        gsWs.sendTXT(num, "pong");
      } else if (msg == "telemetry") {
        String snapshot = gsLatestTelemetryJson();
        gsWs.sendTXT(num, snapshot);
      } else if (msg.startsWith("PAIR:")) {
        // Alternative to HTTP /pair — useful where a browser blocks the
        // cross-origin GET but the WebSocket handshake still goes through.
        const String code = msg.substring(5);
        if (gsCheckPairCode(code.c_str(), code.length())) {
          gsPaired = true;
          gsTelemetryDirty = true;
          gsWs.sendTXT(num, "{\"pair\":\"ok\"}");
          Serial.println("[PAIR] WS OK");
        } else {
          gsWs.sendTXT(num, "{\"pair\":\"fail\"}");
          Serial.println("[PAIR] WS FAIL — wrong code");
        }
      }
      break;
    }

    default:
      break;
  }
}

/// Broadcast one telemetry frame to every WebSocket client. Call from loop().
static void gsWsPushTelemetry() {
  if (!gsPaired || gsWs.connectedClients() == 0) return;

  // Only push packets we have not pushed yet; the rate cap below then thins
  // that stream to 20 Hz. Returning early leaves lastCount untouched, so a
  // packet delayed by the cap is still sent on the next pass.
  static uint32_t lastCount = 0;
  const uint32_t count = gsPacketCount;
  if (count == lastCount) return;

  static uint32_t lastMs = 0;
  const uint32_t now = millis();
  if (lastMs != 0 && (now - lastMs) < GS_TELEM_MIN_INTERVAL_MS) return;

  struct_message snapshot;
  if (!gsCopyTelemetry(snapshot)) return;

  const size_t n = gsBuildTelemetryJson(snapshot, gsNetJsonBuf, sizeof(gsNetJsonBuf));
  if (n == 0) return;

  lastMs = now;
  lastCount = count;
  gsWs.broadcastTXT(gsNetJsonBuf, n);
}

// ============================================================
// UDP discovery  (PROTOCOL — plain text, must start with "CANSATGS")
// ============================================================
// Format: CANSATGS|<ip>|ws=8765|cam=81|http=80|paired=0|telem=1
// The app splits on '|' and uses field 1 as the host; the trailing key=value
// fields are ignored by the app and available to other tooling.

static void gsSendDiscoveryTo(IPAddress dest, const IPAddress &self) {
  char msg[112];
  snprintf(msg, sizeof(msg),
           "CANSATGS|%s|ws=%u|cam=%u|http=%u|paired=%d|telem=%d",
           self.toString().c_str(),
           (unsigned)GS_WS_PORT, (unsigned)GS_CAM_PORT, (unsigned)GS_HTTP_PORT,
           gsPaired ? 1 : 0, gsHasTelemetry ? 1 : 0);

  gsUdp.beginPacket(dest, GS_DISCOVERY_PORT);
  gsUdp.write((const uint8_t *)msg, strlen(msg));
  gsUdp.endPacket();
}

static void gsBroadcastDiscovery() {
  if (gsStaConnected) {
    const IPAddress ip = WiFi.localIP();
    IPAddress subnet = ip;
    subnet[3] = 255;                            // works on most /24 LANs
    gsSendDiscoveryTo(subnet, ip);
    gsSendDiscoveryTo(IPAddress(255, 255, 255, 255), ip);
  }

  if (gsApStarted) {
    const IPAddress apIp = WiFi.softAPIP();
    IPAddress apSubnet = apIp;
    apSubnet[3] = 255;
    gsSendDiscoveryTo(apSubnet, apIp);
  }
}

// ============================================================
// Wi-Fi bring-up
// ============================================================
// AP_STA is deliberate: in pure WIFI_AP the ESP32 often fails to MAC-ACK
// unicast ESP-NOW, which breaks the CanSat/camera channel probing.

static void gsWifiPrepareRadio() {
  WiFi.persistent(false);
  WiFi.disconnect(true);
  delay(100);
  WiFi.mode(WIFI_OFF);
  delay(100);
  WiFi.mode(WIFI_AP_STA);
  WiFi.setSleep(false);
  esp_wifi_set_ps(WIFI_PS_NONE);
  WiFi.setTxPower(WIFI_POWER_19_5dBm);
}

static bool gsStartSoftAp() {
#if !GS_ENABLE_SOFTAP
  return false;
#else
  const char *pass = (sizeof(GS_AP_PASSWORD) - 1 >= 8) ? GS_AP_PASSWORD : nullptr;

  bool ok = WiFi.softAP(GS_AP_SSID, pass, GS_AP_CHANNEL, 0, GS_AP_MAX_CLIENTS);
  if (!ok) {
    Serial.println("[WiFi] softAP with password failed — retrying as OPEN AP");
    ok = WiFi.softAP(GS_AP_SSID, nullptr, GS_AP_CHANNEL, 0, GS_AP_MAX_CLIENTS);
  }
  if (!ok) {
    Serial.println("[WiFi] ERROR: softAP failed");
    return false;
  }

  // The app hard-codes 192.168.4.1 for Wi-Fi mode, so pin it explicitly.
  WiFi.softAPConfig(IPAddress(192, 168, 4, 1),
                    IPAddress(192, 168, 4, 1),
                    IPAddress(255, 255, 255, 0));
  delay(200);

  gsApStarted = true;
  Serial.printf("[WiFi] SoftAP \"%s\" @ %s (channel %d)\n",
                GS_AP_SSID, WiFi.softAPIP().toString().c_str(), WiFi.channel());
  return true;
#endif
}

static bool gsConnectSta(uint32_t timeoutMs) {
  if (!gsStaConfigured()) return false;

  Serial.printf("[WiFi] STA connecting to \"%s\"…\n", GS_STA_SSID);
  WiFi.begin(GS_STA_SSID, GS_STA_PASSWORD);

  const uint32_t start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < timeoutMs) {
    delay(250);
    Serial.print(".");
  }
  Serial.println();

  gsStaConnected = (WiFi.status() == WL_CONNECTED);
  if (gsStaConnected) {
    Serial.printf("[WiFi] STA connected: %s (channel %d)\n",
                  WiFi.localIP().toString().c_str(), WiFi.channel());
    Serial.println("[WiFi] NOTE: the SoftAP now follows the router channel.");
    Serial.println("       CANSAT.ino / Tx_camera_code.ino probe channels 1-13,");
    Serial.println("       so they re-lock onto this station automatically.");
  } else {
    Serial.println("[WiFi] STA connect failed — SoftAP mode still available.");
  }
  return gsStaConnected;
}

/// Lock the radio to the AP channel when there is no router link. With STA
/// connected the channel belongs to the router and must not be forced.
static void gsLockApChannel() {
#if GS_ENABLE_SOFTAP
  if (gsStaConnected || !gsApStarted) return;
  esp_wifi_set_channel(GS_AP_CHANNEL, WIFI_SECOND_CHAN_NONE);
#endif
}

static void gsWifiSetup() {
  gsWifiPrepareRadio();
  gsStartSoftAp();

  if (gsStaConfigured()) {
    gsConnectSta(GS_STA_CONNECT_TIMEOUT_MS);
  }
  gsLockApChannel();

  esp_wifi_set_protocol(WIFI_IF_AP,
                        WIFI_PROTOCOL_11B | WIFI_PROTOCOL_11G | WIFI_PROTOCOL_11N);
  esp_wifi_set_protocol(WIFI_IF_STA,
                        WIFI_PROTOCOL_11B | WIFI_PROTOCOL_11G | WIFI_PROTOCOL_11N);
}

/// Re-attach to the router if it dropped. Non-blocking.
static void gsWifiMaintain() {
  if (!gsStaConfigured()) return;

  static uint32_t lastAttempt = 0;
  const bool up = (WiFi.status() == WL_CONNECTED);

  if (up != gsStaConnected) {
    gsStaConnected = up;
    Serial.printf("[WiFi] STA %s\n", up ? "reconnected" : "lost");
    if (!up) gsLockApChannel();
  }
  if (up) return;

  const uint32_t now = millis();
  if (now - lastAttempt < GS_STA_RETRY_INTERVAL_MS) return;
  lastAttempt = now;
  WiFi.begin(GS_STA_SSID, GS_STA_PASSWORD);
}

static void gsNetSetup() {
  gsHttp.on("/", HTTP_GET, gsHandleRoot);
  gsHttp.on("/health", HTTP_GET, gsHandleHealth);
  gsHttp.on("/telemetry", HTTP_GET, gsHandleTelemetry);
  gsHttp.on("/pair", HTTP_GET, gsHandlePair);
  gsHttp.on("/discover", HTTP_GET, gsHandleDiscover);
  gsHttp.onNotFound(gsHandleNotFound);
  gsHttp.begin();
  Serial.printf("[HTTP] listening on :%u\n", (unsigned)GS_HTTP_PORT);

  gsWs.begin();
  gsWs.onEvent(gsWsEvent);
  Serial.printf("[WS] listening on :%u\n", (unsigned)GS_WS_PORT);

  gsUdp.begin(GS_DISCOVERY_PORT);
  Serial.printf("[UDP] discovery beacon on :%u\n", (unsigned)GS_DISCOVERY_PORT);
}

#endif  // GS_NET_H
