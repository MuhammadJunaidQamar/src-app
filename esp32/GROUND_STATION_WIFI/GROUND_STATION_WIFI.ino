/*
 * CanSat Ground Station — Wi‑Fi SoftAP + WebSocket + ESP-NOW
 *
 * Use this sketch when the Flutter app mode is:
 *   "Wi‑Fi ground station"
 *
 * Phone joins AP "CanSat-GS" (password cansat123), enters the 6-digit
 * pairing code printed on Serial, then receives telemetry over WebSocket.
 *
 * CAMERA: this station also relays the ESP32-CAM video. Flash
 * "Camera working code/Tx_camera_code/Tx_camera_code.ino" with receiverMAC
 * set to THIS board's AP MAC (printed at boot). Received ESP-NOW frame
 * packets are reassembled and served as MJPEG at http://192.168.4.1:81/stream
 * (the app opens it automatically after pairing).
 *
 * Flash: esp32/GROUND_STATION_WIFI/GROUND_STATION_WIFI.ino
 */

#include <esp_now.h>
#include <esp_wifi.h>
#include <string.h>
#include <math.h>
#include <WiFi.h>
#include <WebServer.h>
#include <WebSocketsServer.h>

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
// Point its receiverMAC at THIS board's AP MAC (printed at boot).
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

const char *AP_SSID = "CanSat-GS";
const char *AP_PASSWORD = "cansat123";
const uint16_t WS_PORT = 8765;
const uint16_t CAM_HTTP_PORT = 81;

#ifndef GS_ENABLE_ESPNOW
#define GS_ENABLE_ESPNOW 1
#endif

WebServer httpServer(80);
WebSocketsServer wsServer(WS_PORT);
WiFiServer camServer(CAM_HTTP_PORT);

String latestJson = "{}";
char pairCode[7] = "000000";
bool clientPaired = false;

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

// ── MJPEG camera server (port 81, any GET streams) ──────────────────────────
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

static void onWiFiEvent(WiFiEvent_t event, WiFiEventInfo_t info) {
  (void)info;
#if defined(ARDUINO_EVENT_WIFI_AP_START)
  if (event == ARDUINO_EVENT_WIFI_AP_START) {
    Serial.println("[WiFi] AP started");
  } else if (event == ARDUINO_EVENT_WIFI_AP_STOP) {
    Serial.println("[WiFi] AP stopped");
  }
#endif
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

void prepareWiFiRadio() {
  WiFi.persistent(false);
  WiFi.disconnect(true);
  delay(100);
  WiFi.mode(WIFI_OFF);
  delay(100);
  WiFi.mode(WIFI_AP);
  esp_wifi_set_ps(WIFI_PS_NONE);
  WiFi.setTxPower(WIFI_POWER_19_5dBm);
}

bool startSoftAccessPoint() {
  Serial.println();
  Serial.println("========== Ground Station Wi-Fi ==========");
  const int apChannel = 1;
  const int maxStations = 4;

  bool apOk = WiFi.softAP(AP_SSID, AP_PASSWORD, apChannel, 0, maxStations);
  if (!apOk) {
    Serial.println("softAP(password) failed — retrying OPEN AP.");
    apOk = WiFi.softAP(AP_SSID, NULL, apChannel, 0, maxStations);
  }
  if (!apOk) {
    Serial.println("ERROR: WiFi.softAP failed.");
    return false;
  }

  IPAddress apIp(192, 168, 4, 1);
  IPAddress gateway(192, 168, 4, 1);
  IPAddress subnet(255, 255, 255, 0);
  WiFi.softAPConfig(apIp, gateway, subnet);

  esp_wifi_set_protocol(WIFI_IF_AP,
                        WIFI_PROTOCOL_11B | WIFI_PROTOCOL_11G | WIFI_PROTOCOL_11N);

  wifi_config_t wcfg = {};
  if (esp_wifi_get_config(WIFI_IF_AP, &wcfg) == ESP_OK) {
    wcfg.ap.ssid_hidden = 0;
    esp_wifi_set_config(WIFI_IF_AP, &wcfg);
  }

  delay(200);
  Serial.print("Soft AP SSID: ");
  Serial.println(AP_SSID);
  Serial.print("Soft AP IP: ");
  Serial.println(WiFi.softAPIP());
  Serial.printf("Camera URL  : http://%s:%u/stream\n",
                WiFi.softAPIP().toString().c_str(), (unsigned)CAM_HTTP_PORT);
  Serial.printf("GS MAC (AP) : %s   <-- set as receiverMAC in Tx_camera_code.ino\n",
                WiFi.softAPmacAddress().c_str());
  Serial.println("Join on 2.4 GHz, then enter pairing code from Serial.");
  Serial.println("==========================================");
  return true;
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
      clientPaired = false;
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
    httpServer.send(200, "text/plain",
                    "Ground station ready. WebSocket: ws://192.168.4.1:8765");
  });

  wsServer.begin();
  wsServer.onEvent(onWsEvent);
  httpServer.begin();
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
  Serial.println("  CanSat Ground Station (Wi-Fi AP)");
  Serial.println("  Flash: GROUND_STATION_WIFI.ino");
  Serial.println("  Baud: 115200");
  Serial.println("========================================");

  WiFi.onEvent(onWiFiEvent);
  prepareWiFiRadio();

  if (!startSoftAccessPoint()) {
    Serial.println("FATAL: Soft AP did not start.");
    return;
  }

#if GS_ENABLE_ESPNOW
  if (esp_now_init() != ESP_OK) {
    Serial.println("Error initializing ESP-NOW.");
  } else {
    esp_now_register_recv_cb(OnDataRecv);
    Serial.println("ESP-NOW receive callback registered.");
  }
#else
  Serial.println("GS_ENABLE_ESPNOW=0: ESP-NOW disabled.");
#endif

  configureWebEndpoints();
  camServer.begin();
  regeneratePairCode();
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

  if (telemetryDirty && clientPaired) {
    telemetryDirty = false;
    latestJson = buildTelemetryJson(myData);
    wsServer.broadcastTXT(latestJson);
  } else if (telemetryDirty) {
    telemetryDirty = false;
    latestJson = buildTelemetryJson(myData);
  }

  static unsigned long lastStatus = 0;
  if (millis() - lastStatus > 10000) {
    lastStatus = millis();
    int camViewers = 0;
    for (int i = 0; i < CAM_MAX_CLIENTS; i++) {
      if (camClients[i] && camClients[i].connected()) camViewers++;
    }
    Serial.printf("GS alive | AP %s | stations=%u | paired=%s | telem=%s | "
                  "camFrames=%lu | camViewers=%d\n",
                  WiFi.softAPIP().toString().c_str(),
                  (unsigned)WiFi.softAPgetStationNum(),
                  clientPaired ? "yes" : "no",
                  hasTelemetry ? "yes" : "waiting",
                  (unsigned long)camFrameSeq, camViewers);
  }

  delay(20);
}
