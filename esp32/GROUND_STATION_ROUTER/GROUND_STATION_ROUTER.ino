/*
 * CanSat Ground Station — Router (LAN) + WebSocket + ESP-NOW
 *
 * Use this sketch when the Flutter app mode is:
 *   "Router (LAN) ground station"
 *
 * The ground station joins your Wi‑Fi ROUTER as a normal client. Every
 * phone/laptop running the Flutter app joins the SAME router. The station
 * announces itself with a UDP beacon; the app finds it automatically and the
 * student only enters the 6-digit PAIRING CODE from Serial (115200 baud).
 * Several devices can watch one station at the same time, and each team can
 * only reach their own station because every board has its own pairing code —
 * no broker or backend PC is needed (this replaces the MQTT approach: same
 * router setup, but the station serves telemetry itself over WebSocket).
 *
 * CAMERA: this station also relays the ESP32-CAM video. Flash
 * "Camera working code/Tx_camera_code/Tx_camera_code.ino" with receiverMAC
 * set to THIS board's MAC (printed at boot). Received ESP-NOW frame packets
 * are reassembled and served as MJPEG at  http://<station-ip>:81/stream
 * (the app opens it automatically after pairing).
 *
 * IMPORTANT — ESP-NOW channel:
 *   ESP-NOW only receives on the Wi‑Fi channel this board is on, and the
 *   router decides that channel. CANSAT.ino transmits on channel 1 (its
 *   radio default). If Serial shows "channel: N" with N != 1, either set
 *   your router to channel 1 (2.4 GHz) or make the CanSat switch with
 *   esp_wifi_set_channel(N, WIFI_SECOND_CHAN_NONE) before esp_now_init().
 *
 * Flash: esp32/GROUND_STATION_ROUTER/GROUND_STATION_ROUTER.ino
 */

#include <esp_now.h>
#include <esp_wifi.h>
#include <string.h>
#include <math.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include <WebServer.h>
#include <WebSocketsServer.h>

// ── EDIT THESE for your router ────────────────────────────────────────────────
const char *WIFI_SSID = "UCP-INTERNET";
const char *WIFI_PASSWORD = "internet275";
// ─────────────────────────────────────────────────────────────────────────────

typedef struct struct_message {
  unsigned long Header;
  unsigned long timestamp;
  float Xacc, Yacc, Zacc;
  float Angaccx, Angaccy, Angaccz;
  float roll, pitch, yaw;
  float Magx, Magy, Magz;
  float Temperature, Altitude, Pressure;
  float CompassHeading, GPSHeading;
  float Sat, Lat, Long, GPSAlt;
  float Distance, TotalDistance;
} struct_message;

// Old CANSAT.ino layout — still on many flight boards.
typedef struct legacy_struct_message {
  unsigned long Header;
  float Temperature;
  float Altitude;
  float Pressure;
  float Heading;
  float Xacc, Yacc, Zacc;
  float Angaccx, Angaccy, Angaccz;
  float Magx, Magy, Magz;
  float Sat, Lat, Long, GPSAlt;
  unsigned long TimeStamp;
} legacy_struct_message;

// Camera packet from "Camera working code/Tx_camera_code/Tx_camera_code.ino".
// Point its receiverMAC at THIS board's MAC (printed at boot).
typedef struct __attribute__((packed)) {
  uint16_t frame_id;
  uint16_t packet_id;
  uint16_t total_packets;
  uint16_t size;
  uint8_t data[180];
} CamPacket;
#define CAM_PACKET_LEN 188

struct_message myData;
volatile bool hasTelemetry = false;
volatile bool telemetryDirty = false;

const uint16_t WS_PORT = 8765;
const uint16_t CAM_HTTP_PORT = 81;
// Flutter listens on this port for "CANSATGS|<ip>" beacons (LAN discovery).
const uint16_t DISCOVERY_PORT = 4210;

#ifndef GS_ENABLE_ESPNOW
#define GS_ENABLE_ESPNOW 1
#endif

WebServer httpServer(80);
WebSocketsServer wsServer(WS_PORT);
WiFiServer camServer(CAM_HTTP_PORT);
WiFiUDP discoveryUdp;

String latestJson = "{}";
char pairCode[7] = "000000";
bool clientPaired = false;
bool espNowReady = false;

// ── Camera reassembly (ESP-NOW packets → complete JPEG) ──────────────────────
#define CAM_MAX_FRAME 20000
#define CAM_MAX_PACKETS 160
#define CAM_MAX_CLIENTS 3

static uint8_t camAssembly[CAM_MAX_FRAME];
static bool camGot[CAM_MAX_PACKETS];
static uint16_t camCurFrame = 0xFFFF;
static uint16_t camTotal = 0;
static uint16_t camCount = 0;
static size_t camAssembledLen = 0;

// Latest complete frame, served as MJPEG on port 81.
static uint8_t camJpeg[CAM_MAX_FRAME];
static volatile size_t camJpegLen = 0;
static volatile uint32_t camFrameSeq = 0;

WiFiClient camClients[CAM_MAX_CLIENTS];

static void onCamPacket(const CamPacket &p) {
  if (p.total_packets == 0 || p.total_packets > CAM_MAX_PACKETS) return;
  if (p.packet_id >= p.total_packets || p.size > 180) return;

  if (p.frame_id != camCurFrame || p.total_packets != camTotal) {
    camCurFrame = p.frame_id;
    camTotal = p.total_packets;
    camCount = 0;
    camAssembledLen = 0;
    memset(camGot, 0, sizeof(camGot));
  }

  const size_t off = (size_t)p.packet_id * 180;
  if (off + p.size > CAM_MAX_FRAME) return;

  if (!camGot[p.packet_id]) {
    camGot[p.packet_id] = true;
    camCount++;
    memcpy(camAssembly + off, p.data, p.size);
    if (p.packet_id == p.total_packets - 1) {
      camAssembledLen = off + p.size;
    }
  }

  const bool complete = (camCount == camTotal) && camAssembledLen >= 4;
  if (!complete) return;
  const bool validJpeg = camAssembly[0] == 0xFF && camAssembly[1] == 0xD8 &&
                         camAssembly[camAssembledLen - 2] == 0xFF &&
                         camAssembly[camAssembledLen - 1] == 0xD9;
  if (!validJpeg) return;

  memcpy(camJpeg, camAssembly, camAssembledLen);
  camJpegLen = camAssembledLen;
  camFrameSeq = camFrameSeq + 1;
}

static void ensureOrientationFromImu(struct_message &d) {
  const bool unset =
      (fabsf(d.roll) < 1e-6f && fabsf(d.pitch) < 1e-6f && fabsf(d.yaw) < 1e-6f);
  if (!unset) return;

  const float ax = d.Xacc, ay = d.Yacc, az = d.Zacc;
  const float denom = sqrtf(ay * ay + az * az);
  if (denom > 1e-4f) {
    d.roll = atan2f(ay, az);
    d.pitch = atan2f(-ax, denom);
  }
  d.yaw = d.CompassHeading; // degrees; Flutter converts when |yaw| > 2π
}

static void importLegacyTelemetry(const legacy_struct_message &leg) {
  myData.Header = leg.Header;
  myData.timestamp = leg.TimeStamp;
  myData.Temperature = leg.Temperature;
  myData.Altitude = leg.Altitude;
  myData.Pressure = leg.Pressure;
  myData.CompassHeading = leg.Heading;
  myData.GPSHeading = leg.Heading;
  myData.Xacc = leg.Xacc;
  myData.Yacc = leg.Yacc;
  myData.Zacc = leg.Zacc;
  myData.Angaccx = leg.Angaccx;
  myData.Angaccy = leg.Angaccy;
  myData.Angaccz = leg.Angaccz;
  myData.Magx = leg.Magx;
  myData.Magy = leg.Magy;
  myData.Magz = leg.Magz;
  myData.Sat = leg.Sat;
  myData.Lat = leg.Lat;
  myData.Long = leg.Long;
  myData.GPSAlt = leg.GPSAlt;
  myData.roll = 0;
  myData.pitch = 0;
  myData.yaw = 0;
  myData.Distance = 0;
  myData.TotalDistance = 0;
  ensureOrientationFromImu(myData);
}

static void printTelemetrySerial(const struct_message &d, const char *source) {
  Serial.println("---------- TELEMETRY ----------");
  Serial.printf("source=%s  ts=%lu\n", source, d.timestamp);
  Serial.printf("ENV   temp=%.2f C  alt=%.2f m  press=%.1f Pa\n",
                d.Temperature, d.Altitude, d.Pressure);
  Serial.printf("ACC   ax=%.3f  ay=%.3f  az=%.3f\n", d.Xacc, d.Yacc, d.Zacc);
  Serial.printf("GYRO  gx=%.3f  gy=%.3f  gz=%.3f\n",
                d.Angaccx, d.Angaccy, d.Angaccz);
  Serial.printf("MAG   mx=%.3f  my=%.3f  mz=%.3f  compass=%.1f deg\n",
                d.Magx, d.Magy, d.Magz, d.CompassHeading);
  Serial.printf("ORI   roll=%.4f  pitch=%.4f  yaw=%.2f\n",
                d.roll, d.pitch, d.yaw);
  Serial.printf("GPS   sat=%.0f  lat=%.6f  lon=%.6f  gpsAlt=%.2f\n",
                d.Sat, d.Lat, d.Long, d.GPSAlt);
  if (d.Sat < 1.0f || (fabsf(d.Lat) < 1e-6f && fabsf(d.Long) < 1e-6f)) {
    Serial.println("GPS   NOTE: no fix yet (normal indoors)");
  }
  Serial.println("--------------------------------");
}

String buildTelemetryJson(const struct_message &d) {
  String payload = "{";
  payload += "\"temp\":" + String(d.Temperature, 4) + ",";
  payload += "\"alt\":" + String(d.Altitude, 4) + ",";
  payload += "\"press\":" + String(d.Pressure, 4) + ",";
  payload += "\"seaPress\":" + String(d.Pressure, 4) + ",";
  payload += "\"head\":" + String(d.CompassHeading, 4) + ",";
  payload += "\"ax\":" + String(d.Xacc, 4) + ",";
  payload += "\"ay\":" + String(d.Yacc, 4) + ",";
  payload += "\"az\":" + String(d.Zacc, 4) + ",";
  payload += "\"gx\":" + String(d.Angaccx, 4) + ",";
  payload += "\"gy\":" + String(d.Angaccy, 4) + ",";
  payload += "\"gz\":" + String(d.Angaccz, 4) + ",";
  payload += "\"roll\":" + String(d.roll, 6) + ",";
  payload += "\"pitch\":" + String(d.pitch, 6) + ",";
  payload += "\"yaw\":" + String(d.yaw, 6) + ",";
  payload += "\"mx\":" + String(d.Magx, 4) + ",";
  payload += "\"my\":" + String(d.Magy, 4) + ",";
  payload += "\"mz\":" + String(d.Magz, 4) + ",";
  payload += "\"sat\":" + String(d.Sat, 0) + ",";
  payload += "\"lat\":" + String(d.Lat, 6) + ",";
  payload += "\"lon\":" + String(d.Long, 6) + ",";
  payload += "\"gpsAlt\":" + String(d.GPSAlt, 4) + ",";
  payload += "\"ts\":" + String(d.timestamp);
  payload += "}";
  return payload;
}

void regeneratePairCode() {
  uint32_t n = esp_random() % 1000000UL;
  snprintf(pairCode, sizeof(pairCode), "%06lu", (unsigned long)n);
  clientPaired = false;
  Serial.printf("\n*** PAIRING CODE: %s ***\n\n", pairCode);
}

void broadcastDiscoveryBeacon() {
  if (WiFi.status() != WL_CONNECTED) return;

  char msg[48];
  snprintf(msg, sizeof(msg), "CANSATGS|%s", WiFi.localIP().toString().c_str());

  // Subnet broadcast (…x.255) — works on most campus / home /24 networks.
  IPAddress bcast = WiFi.localIP();
  bcast[3] = 255;
  discoveryUdp.beginPacket(bcast, DISCOVERY_PORT);
  discoveryUdp.write((const uint8_t *)msg, strlen(msg));
  discoveryUdp.endPacket();

  // Global broadcast as a fallback for some routers.
  discoveryUdp.beginPacket(IPAddress(255, 255, 255, 255), DISCOVERY_PORT);
  discoveryUdp.write((const uint8_t *)msg, strlen(msg));
  discoveryUdp.endPacket();
}

void printConnectionCard() {
  Serial.println();
  Serial.println("========== Ground Station (Router) ==========");
  Serial.printf("Router SSID : %s\n", WIFI_SSID);
  Serial.printf("STATION IP  : %s   (app auto-finds this)\n",
                WiFi.localIP().toString().c_str());
  Serial.printf("Wi-Fi channel: %d\n", WiFi.channel());
  if (WiFi.channel() != 1) {
    Serial.println("NOTE: channel != 1. Tx_camera_code.ino auto-finds this");
    Serial.println("channel, but CANSAT.ino transmits on channel 1 — set the");
    Serial.println("router to channel 1 or esp_wifi_set_channel() in CANSAT.ino.");
  }
  Serial.printf("PAIRING CODE: %s   <-- enter ONLY this in the app\n", pairCode);
  Serial.printf("Camera URL  : http://%s:%u/stream\n",
                WiFi.localIP().toString().c_str(), (unsigned)CAM_HTTP_PORT);
  Serial.printf("GS MAC      : %s   <-- set as receiverMAC in Tx_camera_code.ino\n",
                WiFi.macAddress().c_str());
  Serial.println("=============================================");
}

void onWsEvent(uint8_t clientNum, WStype_t type, uint8_t *payload, size_t length) {
  if (type == WStype_CONNECTED) {
    if (clientPaired) {
      wsServer.sendTXT(clientNum, latestJson);
    } else {
      wsServer.sendTXT(clientNum, "{\"pair\":\"required\"}");
    }
  } else if (type == WStype_TEXT) {
    String message;
    message.reserve(length + 8);
    for (size_t i = 0; i < length; i++) {
      message += (char)payload[i];
    }
    if (message == "ping") {
      wsServer.sendTXT(clientNum, "pong");
    }
  }
}

bool connectToRouter() {
  WiFi.persistent(false);
  WiFi.disconnect(true);
  delay(100);
  WiFi.mode(WIFI_OFF);
  delay(100);
  WiFi.mode(WIFI_STA);
  esp_wifi_set_ps(WIFI_PS_NONE);
  WiFi.setTxPower(WIFI_POWER_19_5dBm);
  WiFi.setAutoReconnect(true);

  Serial.printf("Connecting to router \"%s\"", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  const uint32_t timeoutMs = 30000;
  uint32_t started = millis();
  while (WiFi.status() != WL_CONNECTED) {
    if (millis() - started > timeoutMs) {
      Serial.println();
      Serial.println("ERROR: could not join the router within 30 s.");
      Serial.println("Check SSID/password and that the router is 2.4 GHz.");
      return false;
    }
    delay(500);
    Serial.print(".");
  }
  Serial.println(" connected.");
  return true;
}

void initEspNow() {
#if GS_ENABLE_ESPNOW
  if (esp_now_init() != ESP_OK) {
    Serial.println("Error initializing ESP-NOW.");
    return;
  }
  esp_now_register_recv_cb(OnDataRecv);
  espNowReady = true;
  Serial.println("ESP-NOW receive callback registered.");
#else
  Serial.println("GS_ENABLE_ESPNOW=0: ESP-NOW disabled.");
#endif
}

void configureWebEndpoints() {
  httpServer.on("/health", HTTP_GET, []() {
    String body = "{\"status\":\"ok\",\"hasTelemetry\":";
    body += hasTelemetry ? "true" : "false";
    body += ",\"paired\":";
    body += clientPaired ? "true" : "false";
    body += ",\"wsPath\":\"/telemetry\",\"wsPort\":";
    body += String(WS_PORT);
    body += "}";
    httpServer.send(200, "application/json", body);
  });

  httpServer.on("/pair", HTTP_GET, []() {
    if (!httpServer.hasArg("code")) {
      httpServer.send(400, "application/json", "{\"pair\":\"fail\"}");
      return;
    }
    String code = httpServer.arg("code");
    if (code.length() == 6 && code == String(pairCode)) {
      clientPaired = true;
      Serial.println("[PAIR] OK");
      httpServer.send(200, "application/json", "{\"pair\":\"ok\"}");
    } else {
      Serial.println("[PAIR] FAIL");
      httpServer.send(200, "application/json", "{\"pair\":\"fail\"}");
    }
  });

  httpServer.on("/telemetry", HTTP_GET, []() {
    if (!clientPaired) {
      httpServer.send(403, "application/json", "{\"pair\":\"required\"}");
      return;
    }
    httpServer.send(200, "application/json", latestJson);
  });

  httpServer.onNotFound([]() {
    String msg = "Ground station ready. WebSocket: ws://";
    msg += WiFi.localIP().toString();
    msg += ":" + String(WS_PORT);
    httpServer.send(200, "text/plain", msg);
  });

  wsServer.begin();
  wsServer.onEvent(onWsEvent);
  httpServer.begin();
}

// ── MJPEG camera server (port 81, path irrelevant — any GET streams) ────────
static void acceptCameraClients() {
  WiFiClient nc = camServer.available();
  if (!nc) return;

  // Drain the HTTP request line/headers (best-effort, don't block the loop).
  uint32_t t0 = millis();
  while (nc.connected() && !nc.available() && millis() - t0 < 150) delay(1);
  while (nc.available()) nc.read();

  if (!clientPaired) {
    nc.print("HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n");
    nc.stop();
    return;
  }

  for (int i = 0; i < CAM_MAX_CLIENTS; i++) {
    if (!camClients[i] || !camClients[i].connected()) {
      camClients[i].stop();
      camClients[i] = nc;
      camClients[i].print(
          "HTTP/1.1 200 OK\r\n"
          "Content-Type: multipart/x-mixed-replace; boundary=frame\r\n"
          "Cache-Control: no-cache\r\n"
          "Connection: keep-alive\r\n\r\n");
      Serial.printf("[CAM] viewer connected (slot %d)\n", i);
      return;
    }
  }

  nc.print("HTTP/1.1 503 Service Unavailable\r\nConnection: close\r\n\r\n");
  nc.stop();
}

static void pushCameraFrame() {
  static uint32_t lastSentSeq = 0;
  const uint32_t seq = camFrameSeq;
  const size_t len = camJpegLen;
  if (seq == lastSentSeq || len == 0) return;
  lastSentSeq = seq;

  for (int i = 0; i < CAM_MAX_CLIENTS; i++) {
    if (!camClients[i] || !camClients[i].connected()) continue;
    camClients[i].printf(
        "--frame\r\nContent-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n",
        (unsigned)len);
    camClients[i].write(camJpeg, len);
    camClients[i].print("\r\n");
  }
}

void OnDataRecv(const esp_now_recv_info_t *recv_info, const uint8_t *incomingData, int len) {
  (void)recv_info;
  const char *src = "unknown";

  if (len == CAM_PACKET_LEN) {
    CamPacket p;
    memcpy(&p, incomingData, sizeof(p));
    onCamPacket(p);
    return;
  }

  if (len == (int)sizeof(struct_message)) {
    memcpy(&myData, incomingData, sizeof(myData));
    ensureOrientationFromImu(myData);
    src = "new-struct";
  } else if (len == (int)sizeof(legacy_struct_message)) {
    legacy_struct_message leg;
    memcpy(&leg, incomingData, sizeof(leg));
    importLegacyTelemetry(leg);
    src = "legacy-CANSAT";
  } else {
    Serial.printf("[ESP-NOW] ignored len=%d (expect %u or %u)\n", len,
                  (unsigned)sizeof(struct_message),
                  (unsigned)sizeof(legacy_struct_message));
    return;
  }

  hasTelemetry = true;
  telemetryDirty = true;

  static uint32_t lastPrintMs = 0;
  if (millis() - lastPrintMs >= 1000) {
    lastPrintMs = millis();
    printTelemetrySerial(myData, src);
  }
}

void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println();
  Serial.println("========================================");
  Serial.println("  CanSat Ground Station (Router / LAN)");
  Serial.println("  Flash: GROUND_STATION_ROUTER.ino");
  Serial.println("  Baud: 115200");
  Serial.println("========================================");

  if (!connectToRouter()) {
    Serial.println("FATAL: no router connection. Fix Wi-Fi and reset.");
    return;
  }

  // ESP-NOW must start after the STA is up so it sits on the router's channel.
  initEspNow();

  configureWebEndpoints();
  camServer.begin();
  discoveryUdp.begin(DISCOVERY_PORT);
  regeneratePairCode();
  printConnectionCard();
  Serial.printf("[BOOT] packet sizes: new=%u legacy=%u\n",
                (unsigned)sizeof(struct_message),
                (unsigned)sizeof(legacy_struct_message));
  Serial.println("Receiver ready...");
}

void loop() {
  wsServer.loop();
  httpServer.handleClient();
  acceptCameraClients();
  pushCameraFrame();

  if (telemetryDirty) {
    telemetryDirty = false;
    latestJson = buildTelemetryJson(myData);
    if (clientPaired) {
      wsServer.broadcastTXT(latestJson);
    }
  }

  static unsigned long lastBeacon = 0;
  if (millis() - lastBeacon >= 2000) {
    lastBeacon = millis();
    broadcastDiscoveryBeacon();
  }

  static unsigned long lastStatus = 0;
  if (millis() - lastStatus > 10000) {
    lastStatus = millis();
    if (WiFi.status() == WL_CONNECTED) {
      int camViewers = 0;
      for (int i = 0; i < CAM_MAX_CLIENTS; i++) {
        if (camClients[i] && camClients[i].connected()) camViewers++;
      }
      Serial.printf(
          "GS alive | IP %s | ch=%d | rssi=%d dBm | code=%s | paired=%s | "
          "telem=%s | camFrames=%lu | camViewers=%d\n",
          WiFi.localIP().toString().c_str(), WiFi.channel(), WiFi.RSSI(),
          pairCode, clientPaired ? "yes" : "no",
          hasTelemetry ? "yes" : "waiting",
          (unsigned long)camFrameSeq, camViewers);
    } else {
      Serial.println("GS alive | Wi-Fi DISCONNECTED — reconnecting...");
    }
  }

  delay(20);
}
