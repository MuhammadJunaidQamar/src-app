/*
  APEXech Ground Station Gateway
  --------------------------------
  ESP-NOW telemetry receiver + BLE GATT + Wi-Fi AP/STA + WebSocket + HTTP
  + UDP discovery.

  Based on the original Ground_station_code(1).ino.

  IMPORTANT:
  1. Keep the telemetry struct identical to the CanSat transmitter.
  2. ESP-NOW uses the active Wi-Fi radio channel. In STA mode, the
     Ground Station follows the router's channel. In SoftAP mode, the
     AP channel is fixed by SOFTAP_CHANNEL.
  3. The MJPEG endpoint is a camera endpoint placeholder unless a camera
     is physically connected to this Ground Station ESP32. The original
     uploaded code contained no camera driver/pin configuration.
  4. Install these libraries in Arduino IDE:
       - NimBLE-Arduino
       - WebSockets by Markus Sattler
     WiFi, WebServer, WiFiUdp, and ESP-NOW come with the ESP32 core.

  Network interfaces:
       HTTP       :80
       WebSocket  :8765
       MJPEG      :81
       UDP        :4210
       BLE        : APEXech Ground Station GATT
*/

#include <WiFi.h>
#include <WebServer.h>
#include <WiFiUdp.h>
#include <esp_now.h>
#include <NimBLEDevice.h>
#include <WebSocketsServer.h>

// ============================================================
// USER CONFIGURATION
// ============================================================

// Wi-Fi SoftAP
const char* AP_SSID     = "internet";
const char* AP_PASSWORD = "netnetnet2";
const uint8_t SOFTAP_CHANNEL = 6;

// STA/router mode.
// Set to your router/hotspot credentials.
const char* STA_SSID     = "";
const char* STA_PASSWORD = "";

// Start SoftAP always. STA starts only if STA_SSID is not empty.
const bool ENABLE_SOFTAP = true;
const bool ENABLE_STA    = true;

// Serial output:
// true = preserve original binary telemetry output for MATLAB/PC.
// false = don't send binary packets to Serial.
const bool SERIAL_BINARY_TELEMETRY = true;

// UDP discovery
const uint16_t UDP_DISCOVERY_PORT = 4210;
const uint32_t DISCOVERY_INTERVAL_MS = 2000;

// ============================================================
// TELEMETRY STRUCT - KEEP IDENTICAL TO CAN SAT TRANSMITTER
// ============================================================

typedef struct struct_message {
  unsigned long Header;
  float Temperature;
  float Altitude;
  float Pressure;
  float Heading;
  float Xacc;
  float Yacc;
  float Zacc;
  float Angaccx;
  float Angaccy;
  float Angaccz;
  float Magx;
  float Magy;
  float Magz;
  float Sat;
  float Lat;
  float Long;
  float GPSAlt;
  unsigned long TimeStamp;
} struct_message;

struct_message myData;

// ============================================================
// NETWORK SERVERS
// ============================================================

WebServer httpServer(80);
WebServer cameraServer(81);
WebSocketsServer webSocket(8765);
WiFiUDP udp;

// ============================================================
// TELEMETRY STATE
// ============================================================

portMUX_TYPE telemetryMux = portMUX_INITIALIZER_UNLOCKED;

volatile bool telemetryReady = false;
volatile uint32_t telemetryPacketCount = 0;
volatile uint32_t telemetryErrorCount = 0;

struct_message latestTelemetry;
unsigned long lastTelemetryMillis = 0;
uint8_t lastCanSatMac[6] = {0};

String lastSourceMac = "00:00:00:00:00:00";

// ============================================================
// BLE
// ============================================================

NimBLEServer* bleServer = nullptr;
NimBLECharacteristic* bleTelemetryCharacteristic = nullptr;
NimBLECharacteristic* bleStatusCharacteristic = nullptr;

bool bleClientConnected = false;

#define BLE_SERVICE_UUID       "7d7e1000-8e1b-4b4c-9c01-000000000001"
#define BLE_TELEMETRY_UUID     "7d7e1000-8e1b-4b4c-9c01-000000000002"
#define BLE_STATUS_UUID        "7d7e1000-8e1b-4b4c-9c01-000000000003"
#define BLE_CAMERA_UUID        "7d7e1000-8e1b-4b4c-9c01-000000000004"

// Camera characteristic is reserved for future camera packets.
// Do not push a continuous MJPEG stream through BLE.
NimBLECharacteristic* bleCameraCharacteristic = nullptr;

// ============================================================
// HELPERS
// ============================================================

String macToString(const uint8_t* mac) {
  char s[18];
  snprintf(s, sizeof(s),
           "%02X:%02X:%02X:%02X:%02X:%02X",
           mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  return String(s);
}

String jsonEscape(const String& input) {
  String output;
  output.reserve(input.length() + 8);

  for (size_t i = 0; i < input.length(); i++) {
    char c = input[i];
    if (c == '"' || c == '\\') {
      output += '\\';
    }
    if (c == '\n') {
      output += "\\n";
    } else if (c == '\r') {
      output += "\\r";
    } else {
      output += c;
    }
  }
  return output;
}

bool copyLatestTelemetry(struct_message& destination) {
  bool available;

  portENTER_CRITICAL(&telemetryMux);
  destination = latestTelemetry;
  available = telemetryReady;
  portEXIT_CRITICAL(&telemetryMux);

  return available;
}

String telemetryToJson() {
  struct_message t;

  if (!copyLatestTelemetry(t)) {
    return "{\"status\":\"waiting_for_telemetry\"}";
  }

  String json;
  json.reserve(1100);

  json += "{";
  json += "\"header\":" + String(t.Header) + ",";
  json += "\"temperature\":" + String(t.Temperature, 3) + ",";
  json += "\"altitude\":" + String(t.Altitude, 3) + ",";
  json += "\"pressure\":" + String(t.Pressure, 3) + ",";
  json += "\"heading\":" + String(t.Heading, 3) + ",";

  json += "\"acceleration\":{";
  json += "\"x\":" + String(t.Xacc, 3) + ",";
  json += "\"y\":" + String(t.Yacc, 3) + ",";
  json += "\"z\":" + String(t.Zacc, 3);
  json += "},";

  json += "\"gyro\":{";
  json += "\"x\":" + String(t.Angaccx, 3) + ",";
  json += "\"y\":" + String(t.Angaccy, 3) + ",";
  json += "\"z\":" + String(t.Angaccz, 3);
  json += "},";

  json += "\"magnetometer\":{";
  json += "\"x\":" + String(t.Magx, 3) + ",";
  json += "\"y\":" + String(t.Magy, 3) + ",";
  json += "\"z\":" + String(t.Magz, 3);
  json += "},";

  json += "\"gps\":{";
  json += "\"satellites\":" + String(t.Sat, 0) + ",";
  json += "\"latitude\":" + String(t.Lat, 7) + ",";
  json += "\"longitude\":" + String(t.Long, 7) + ",";
  json += "\"altitude\":" + String(t.GPSAlt, 3);
  json += "},";

  json += "\"timestamp\":" + String(t.TimeStamp) + ",";
  json += "\"packet_count\":" + String(telemetryPacketCount) + ",";
  json += "\"source_mac\":\"" + jsonEscape(lastSourceMac) + "\"";
  json += "}";

  return json;
}

// ============================================================
// ESP-NOW RECEIVE
// ============================================================

void OnDataRecv(const esp_now_recv_info_t *recv_info,
                const uint8_t *incomingData,
                int len) {

  // Prevent unsafe memcpy if a bad/short packet arrives.
  if (len != sizeof(struct_message)) {
    portENTER_CRITICAL(&telemetryMux);
    telemetryErrorCount++;
    portEXIT_CRITICAL(&telemetryMux);
    return;
  }

  struct_message received;
  memcpy(&received, incomingData, sizeof(received));

  portENTER_CRITICAL(&telemetryMux);
  latestTelemetry = received;
  telemetryReady = true;
  telemetryPacketCount++;
  lastTelemetryMillis = millis();
  memcpy(lastCanSatMac, recv_info->src_addr, 6);
  portEXIT_CRITICAL(&telemetryMux);

  lastSourceMac = macToString(recv_info->src_addr);

  // Preserve original binary serial output.
  if (SERIAL_BINARY_TELEMETRY) {
    Serial.write((uint8_t*)&received, sizeof(received));
  }
}

// ============================================================
// BLE CALLBACKS
// ============================================================

class GroundStationServerCallbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer* server, NimBLEConnInfo& connInfo) override {
    bleClientConnected = true;
    Serial.println("\n[BLE] Flutter client connected");
  }

  void onDisconnect(NimBLEServer* server, NimBLEConnInfo& connInfo, int reason) override {
    bleClientConnected = false;
    Serial.println("\n[BLE] Flutter client disconnected");

    NimBLEDevice::startAdvertising();
  }
};

void setupBLE() {
  NimBLEDevice::init("APEXech-GS");

  bleServer = NimBLEDevice::createServer();
  bleServer->setCallbacks(new GroundStationServerCallbacks());

  NimBLEService* service =
      bleServer->createService(BLE_SERVICE_UUID);

  bleTelemetryCharacteristic =
      service->createCharacteristic(
          BLE_TELEMETRY_UUID,
          NIMBLE_PROPERTY::READ |
          NIMBLE_PROPERTY::NOTIFY);

  bleStatusCharacteristic =
      service->createCharacteristic(
          BLE_STATUS_UUID,
          NIMBLE_PROPERTY::READ |
          NIMBLE_PROPERTY::NOTIFY);

  bleCameraCharacteristic =
      service->createCharacteristic(
          BLE_CAMERA_UUID,
          NIMBLE_PROPERTY::READ |
          NIMBLE_PROPERTY::NOTIFY);

  bleTelemetryCharacteristic->setValue(
      "{\"status\":\"waiting_for_telemetry\"}");

  bleStatusCharacteristic->setValue(
      "{\"device\":\"APEXech-GS\",\"status\":\"online\"}");

  service->start();

  NimBLEAdvertising* advertising = NimBLEDevice::getAdvertising();
  advertising->addServiceUUID(BLE_SERVICE_UUID);
  advertising->setName("APEXech-GS");
  advertising->start();

  Serial.println("[BLE] Advertising as APEXech-GS");
}

// ============================================================
// WIFI
// ============================================================

void setupWiFi() {
  WiFi.mode(WIFI_MODE_APSTA);
  WiFi.setSleep(false);

  if (ENABLE_SOFTAP) {
    bool apOK = WiFi.softAP(
        AP_SSID,
        AP_PASSWORD,
        SOFTAP_CHANNEL,
        false,
        4
    );

    if (apOK) {
      Serial.println("[WiFi] SoftAP started");
      Serial.print("[WiFi] AP SSID: ");
      Serial.println(AP_SSID);
      Serial.print("[WiFi] AP IP: ");
      Serial.println(WiFi.softAPIP());
      Serial.print("[WiFi] AP channel: ");
      Serial.println(WiFi.channel());
    } else {
      Serial.println("[WiFi] SoftAP start FAILED");
    }
  }

  if (ENABLE_STA && strlen(STA_SSID) > 0) {
    Serial.print("[WiFi] Connecting STA to: ");
    Serial.println(STA_SSID);

    WiFi.begin(STA_SSID, STA_PASSWORD);

    unsigned long start = millis();

    while (WiFi.status() != WL_CONNECTED &&
           millis() - start < 15000) {
      delay(250);
      Serial.print(".");
    }

    Serial.println();

    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("[WiFi] STA connected");
      Serial.print("[WiFi] STA IP: ");
      Serial.println(WiFi.localIP());
      Serial.print("[WiFi] STA channel: ");
      Serial.println(WiFi.channel());
    } else {
      Serial.println("[WiFi] STA connection failed");
    }
  }

  WiFi.onEvent([](WiFiEvent_t event, WiFiEventInfo_t info) {
    if (event == ARDUINO_EVENT_WIFI_STA_GOT_IP) {
      Serial.print("[WiFi] STA IP acquired: ");
      Serial.println(WiFi.localIP());
    }
  });
}

// ============================================================
// HTTP SERVER :80
// ============================================================

void handleRoot() {
  String html;
  html.reserve(1800);

  html += "<!doctype html><html><head>";
  html += "<meta name='viewport' content='width=device-width,initial-scale=1'>";
  html += "<title>APEXech Ground Station</title></head><body>";
  html += "<h1>APEXech Ground Station</h1>";
  html += "<p>Status: ONLINE</p>";
  html += "<p>HTTP: 80</p>";
  html += "<p>WebSocket: 8765</p>";
  html += "<p>MJPEG: 81</p>";
  html += "<p>UDP discovery: 4210</p>";
  html += "<p><a href='/health'>Health</a></p>";
  html += "<p><a href='/telemetry'>Telemetry</a></p>";
  html += "<p><a href='/pair'>Pairing</a></p>";
  html += "</body></html>";

  httpServer.send(200, "text/html", html);
}

void handleHealth() {
  String json = "{";
  json += "\"device\":\"APEXech-GS\",";
  json += "\"status\":\"online\",";
  json += "\"uptime_ms\":" + String(millis()) + ",";
  json += "\"telemetry_received\":" + String(telemetryReady ? "true" : "false") + ",";
  json += "\"packet_count\":" + String(telemetryPacketCount) + ",";
  json += "\"packet_errors\":" + String(telemetryErrorCount) + ",";
  json += "\"ble_connected\":" + String(bleClientConnected ? "true" : "false") + ",";
  json += "\"wifi_ap_ip\":\"" + WiFi.softAPIP().toString() + "\",";
  json += "\"wifi_sta_ip\":\"" + WiFi.localIP().toString() + "\"";
  json += "}";

  httpServer.send(200, "application/json", json);
}

void handleTelemetry() {
  httpServer.send(200, "application/json", telemetryToJson());
}

void handlePair() {
  String json = "{";
  json += "\"device\":\"APEXech-GS\",";
  json += "\"name\":\"APEXech Ground Station\",";
  json += "\"ble_name\":\"APEXech-GS\",";
  json += "\"http_port\":80,";
  json += "\"websocket_port\":8765,";
  json += "\"camera_port\":81,";
  json += "\"discovery_port\":4210,";
  json += "\"softap_ip\":\"" + WiFi.softAPIP().toString() + "\",";
  json += "\"sta_ip\":\"" + WiFi.localIP().toString() + "\"";
  json += "}";

  httpServer.send(200, "application/json", json);
}

void handleNotFound() {
  httpServer.send(404, "application/json",
                  "{\"error\":\"not_found\"}");
}

void setupHTTP() {
  httpServer.on("/", HTTP_GET, handleRoot);
  httpServer.on("/health", HTTP_GET, handleHealth);
  httpServer.on("/telemetry", HTTP_GET, handleTelemetry);
  httpServer.on("/pair", HTTP_GET, handlePair);
  httpServer.onNotFound(handleNotFound);

  httpServer.begin();

  Serial.println("[HTTP] Server started on port 80");
}

// ============================================================
// WEBSOCKET :8765
// ============================================================

void webSocketEvent(
    uint8_t num,
    WStype_t type,
    uint8_t *payload,
    size_t length) {

  switch (type) {

    case WStype_CONNECTED: {
      IPAddress ip = webSocket.remoteIP(num);

      Serial.print("[WS] Client connected: ");
      Serial.println(ip);

      webSocket.sendTXT(
          num,
          "{\"device\":\"APEXech-GS\",\"status\":\"connected\"}"
      );

      break;
    }

    case WStype_DISCONNECTED:
      Serial.println("[WS] Client disconnected");
      break;

    case WStype_TEXT:
      // Basic commands from Flutter.
      if (length > 0) {
        String command = String((char*)payload);

        if (command == "ping") {
          webSocket.sendTXT(num, "{\"pong\":true}");
        } else if (command == "telemetry") {
          String telemetryJson = telemetryToJson();
          webSocket.sendTXT(num, telemetryJson);
        } else if (command == "health") {
          String health =
              "{\"status\":\"online\",\"uptime_ms\":" +
              String(millis()) + "}";
          webSocket.sendTXT(num, health);
        }
      }
      break;

    default:
      break;
  }
}

void setupWebSocket() {
  webSocket.begin();
  webSocket.onEvent(webSocketEvent);

  Serial.println("[WS] WebSocket server started on port 8765");
}

// ============================================================
// MJPEG SERVER :81
// ============================================================

void setupCameraServer() {

  /*
     The original Ground_station_code(1).ino has no camera object,
     sensor configuration, or camera pins.

     Therefore this server intentionally reports that the camera
     hardware is not configured instead of pretending that a stream
     exists.

     When a camera module is attached, replace handleCameraStream()
     with the camera capture/streaming implementation for that
     exact ESP32 camera board.
  */

  cameraServer.on("/", HTTP_GET, []() {
    cameraServer.send(
        200,
        "text/html",
        "<h1>APEXech Camera Server</h1>"
        "<p>Camera hardware is not configured in this firmware.</p>"
        "<p>MJPEG endpoint reserved on port 81.</p>"
    );
  });

  cameraServer.on("/stream", HTTP_GET, []() {
    cameraServer.send(
        503,
        "application/json",
        "{\"camera\":\"not_configured\","
        "\"message\":\"Connect/configure camera hardware for MJPEG streaming\"}"
    );
  });

  cameraServer.begin();

  Serial.println("[CAM] HTTP camera server started on port 81");
  Serial.println("[CAM] /stream reserved for MJPEG");
}

// ============================================================
// UDP DISCOVERY :4210
// ============================================================

String discoveryJson() {

  String json = "{";
  json += "\"device\":\"APEXech-GS\",";
  json += "\"type\":\"ground_station\",";
  json += "\"version\":\"1.0\",";
  json += "\"http_port\":80,";
  json += "\"websocket_port\":8765,";
  json += "\"camera_port\":81,";
  json += "\"discovery_port\":4210,";
  json += "\"ble_name\":\"APEXech-GS\",";

  json += "\"softap_ip\":\"" + WiFi.softAPIP().toString() + "\",";

  if (WiFi.status() == WL_CONNECTED) {
    json += "\"sta_ip\":\"" + WiFi.localIP().toString() + "\",";
  } else {
    json += "\"sta_ip\":\"\",";
  }

  json += "\"telemetry\":";
  json += telemetryReady ? "true" : "false";
  json += "}";

  return json;
}

void sendDiscoveryBeacon() {

  String payload = discoveryJson();

  // Broadcast to the local network.
  udp.beginPacket(IPAddress(255, 255, 255, 255),
                  UDP_DISCOVERY_PORT);
  udp.print(payload);
  udp.endPacket();
}

// ============================================================
// TELEMETRY DISTRIBUTION
// ============================================================

uint32_t lastBroadcastPacketCount = 0;

void distributeTelemetry() {

  uint32_t currentCount;

  portENTER_CRITICAL(&telemetryMux);
  currentCount = telemetryPacketCount;
  portEXIT_CRITICAL(&telemetryMux);

  if (!telemetryReady || currentCount == lastBroadcastPacketCount) {
    return;
  }

  lastBroadcastPacketCount = currentCount;

  String json = telemetryToJson();

  // WebSocket telemetry notify.
  webSocket.broadcastTXT(json);

  // BLE telemetry notify.
  if (bleTelemetryCharacteristic != nullptr) {
    bleTelemetryCharacteristic->setValue(json.c_str());
    if (bleClientConnected) {
      bleTelemetryCharacteristic->notify();
    }
  }
}

// ============================================================
// STATUS
// ============================================================

unsigned long lastStatusPrint = 0;

void printStatus() {

  if (millis() - lastStatusPrint < 5000) {
    return;
  }

  lastStatusPrint = millis();

  Serial.println();
  Serial.println("========== APEXech GROUND STATION ==========");

  Serial.print("ESP-NOW packets: ");
  Serial.println(telemetryPacketCount);

  Serial.print("ESP-NOW errors: ");
  Serial.println(telemetryErrorCount);

  Serial.print("Last source MAC: ");
  Serial.println(lastSourceMac);

  Serial.print("Telemetry: ");
  Serial.println(telemetryReady ? "AVAILABLE" : "WAITING");

  Serial.print("BLE: ");
  Serial.println(bleClientConnected ? "CONNECTED" : "ADVERTISING");

  Serial.print("SoftAP IP: ");
  Serial.println(WiFi.softAPIP());

  Serial.print("STA IP: ");
  Serial.println(WiFi.localIP());

  Serial.print("Wi-Fi channel: ");
  Serial.println(WiFi.channel());

  Serial.println("============================================");
}

// ============================================================
// SETUP
// ============================================================

void setup() {

  Serial.begin(115200);
  delay(500);

  Serial.println();
  Serial.println("============================================");
  Serial.println("      CanSat GROUND STATION GATEWAY");
  Serial.println("============================================");

  // Wi-Fi must be configured before ESP-NOW.
  setupWiFi();

  // ESP-NOW
  if (esp_now_init() != ESP_OK) {
    Serial.println("[ESP-NOW] ERROR: initialization failed");
    return;
  }

  esp_now_register_recv_cb(OnDataRecv);

  Serial.println("[ESP-NOW] Receiver ready");

  // BLE
  setupBLE();

  // HTTP
  setupHTTP();

  // WebSocket
  setupWebSocket();

  // Camera server
  setupCameraServer();

  // UDP
  udp.begin(UDP_DISCOVERY_PORT);

  Serial.print("[UDP] Discovery port: ");
  Serial.println(UDP_DISCOVERY_PORT);

  Serial.println();
  Serial.println("Ground Station services:");
  Serial.println("  BLE GATT       -> APEXech-GS");
  Serial.println("  HTTP           -> :80");
  Serial.println("  WebSocket      -> :8765");
  Serial.println("  MJPEG          -> :81/stream");
  Serial.println("  UDP discovery  -> :4210");
  Serial.println();
}

// ============================================================
// LOOP
// ============================================================

unsigned long lastDiscovery = 0;

void loop() {

  // HTTP
  httpServer.handleClient();
  cameraServer.handleClient();

  // WebSocket
  webSocket.loop();

  // Send newly received telemetry to Flutter.
  distributeTelemetry();

  // UDP discovery beacon.
  if (millis() - lastDiscovery >= DISCOVERY_INTERVAL_MS) {
    lastDiscovery = millis();
    sendDiscoveryBeacon();
  }

  // Diagnostic status.
  printStatus();

  delay(2);
}
