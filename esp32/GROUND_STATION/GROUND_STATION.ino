#include <esp_now.h>
#include <esp_wifi.h>
#include <string.h>
#include <WiFi.h>
#include <WebServer.h>
#include <WebSocketsServer.h>

// Updated Struct for RF Data with roll, pitch, yaw and all parameters
typedef struct struct_message {
  // Header and basic info
  unsigned long Header;
  unsigned long timestamp;
  
  // IMU data
  float Xacc;
  float Yacc;
  float Zacc;
  float Angaccx;
  float Angaccy;
  float Angaccz;
  
  // Orientation (new fields)
  float roll;
  float pitch;
  float yaw;
  
  // Magnetometer data
  float Magx;
  float Magy;
  float Magz;
  
  // Environmental data
  float Temperature;
  float Altitude;
  float Pressure;
  
  // Compass data
  float CompassHeading;
  float GPSHeading;
  
  // GPS data
  float Sat;
  float Lat;
  float Long;
  float GPSAlt;
  
  // Distance tracking
  float Distance;
  float TotalDistance;
} struct_message;

// Create a struct_message called myData
struct_message myData;
volatile bool hasTelemetry = false;
volatile bool telemetryDirty = false;

// Ground-station AP + telemetry server settings.
const char *AP_SSID = "CanSat-GS";
const char *AP_PASSWORD = "cansat123";
const uint16_t WS_PORT = 8765;

// 1 = normal (AP + ESP-NOW). Set to 0 only to debug Wi-Fi without ESP-NOW.
#ifndef GS_ENABLE_ESPNOW
#define GS_ENABLE_ESPNOW 1
#endif

WebServer httpServer(80);
WebSocketsServer wsServer(WS_PORT);

String latestJson = "{}";

String buildTelemetryJson(const struct_message &d) {
  String payload = "{";
  payload += "\"temp\":" + String(d.Temperature, 4) + ",";
  payload += "\"alt\":" + String(d.Altitude, 4) + ",";
  payload += "\"press\":" + String(d.Pressure, 4) + ",";
  payload += "\"head\":" + String(d.CompassHeading, 4) + ",";
  payload += "\"ax\":" + String(d.Xacc, 4) + ",";
  payload += "\"ay\":" + String(d.Yacc, 4) + ",";
  payload += "\"az\":" + String(d.Zacc, 4) + ",";
  payload += "\"gx\":" + String(d.Angaccx, 4) + ",";
  payload += "\"gy\":" + String(d.Angaccy, 4) + ",";
  payload += "\"gz\":" + String(d.Angaccz, 4) + ",";
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

static void onWiFiEvent(WiFiEvent_t event, WiFiEventInfo_t info) {
  (void)info;
#if defined(ARDUINO_EVENT_WIFI_AP_START)
  if (event == ARDUINO_EVENT_WIFI_AP_START) {
    Serial.println("[WiFi] ARDUINO_EVENT_WIFI_AP_START — AP beacon should be active.");
  } else if (event == ARDUINO_EVENT_WIFI_AP_STOP) {
    Serial.println("[WiFi] ARDUINO_EVENT_WIFI_AP_STOP");
  }
#endif
}

void onWsEvent(uint8_t clientNum, WStype_t type, uint8_t *payload, size_t length) {
  if (type == WStype_CONNECTED) {
    wsServer.sendTXT(clientNum, latestJson);
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

// Only sets mode / power — do not call softAP() here (see setup order).
void prepareWiFiRadio() {
  WiFi.persistent(false);
  WiFi.disconnect(true);
  delay(100);
  WiFi.mode(WIFI_OFF);
  delay(100);
  // AP-only: no STA interface (we do not call WiFi.begin). Matches Espressif ESP-NOW + SoftAP slave flow.
  WiFi.mode(WIFI_AP);
  esp_wifi_set_ps(WIFI_PS_NONE);
  WiFi.setTxPower(WIFI_POWER_19_5dBm);
}

bool startSoftAccessPoint() {
  Serial.println();
  Serial.println("========== Ground Station Wi-Fi ==========");

  const int apChannel = 1;   // 1 is most compatible; try 6 or 11 if needed
  const int maxStations = 4;

  bool apOk = WiFi.softAP(AP_SSID, AP_PASSWORD, apChannel, 0, maxStations);
  if (!apOk) {
    Serial.println("softAP(password) failed — retrying OPEN AP (no password).");
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

  // Ensure SSID is broadcast (some paths leave ssid_hidden set).
  wifi_config_t wcfg = {};
  if (esp_wifi_get_config(WIFI_IF_AP, &wcfg) == ESP_OK) {
    wcfg.ap.ssid_hidden = 0;
    if (esp_wifi_set_config(WIFI_IF_AP, &wcfg) != ESP_OK) {
      Serial.println("Note: esp_wifi_set_config (visible SSID) failed.");
    }
  }
  wifi_config_t wcfgRead = {};
  uint8_t ssidHiddenReport = 255;
  if (esp_wifi_get_config(WIFI_IF_AP, &wcfgRead) == ESP_OK) {
    ssidHiddenReport = wcfgRead.ap.ssid_hidden;
  }

  delay(200);

  uint8_t primaryChan = 0;
  wifi_second_chan_t secondChan = WIFI_SECOND_CHAN_NONE;
  esp_wifi_get_channel(&primaryChan, &secondChan);

  Serial.print("Soft AP SSID (scan for this): ");
  Serial.println(AP_SSID);
  if (ssidHiddenReport != 255) {
    Serial.printf("AP ssid_hidden from driver: %u (0=broadcast)\n", (unsigned)ssidHiddenReport);
  }
  Serial.print("Soft AP IP: ");
  Serial.println(WiFi.softAPIP());
  Serial.printf("Radio channel (reported): %u\n", primaryChan);
  uint8_t m[6];
  WiFi.softAPmacAddress(m);
  Serial.printf("Soft AP MAC: %02X:%02X:%02X:%02X:%02X:%02X\n", m[0], m[1], m[2], m[3], m[4], m[5]);
  Serial.printf("WiFi.getMode()=%d (expect 2=WIFI_AP)\n", (int)WiFi.getMode());
  Serial.println("Use 2.4 GHz Wi-Fi on the phone (ESP32 has no 5 GHz AP).");
  Serial.println("Still no SSID? Android: Location ON. Try Add network with SSID + password.");
  Serial.println("Hardware check: flash esp32/smoke_ap/smoke_ap.ino (SSID ESP-SMOKE). If that fails too, radio/USB/antenna.");
  Serial.println("==========================================");
  return true;
}

void configureWebEndpoints() {
  httpServer.on("/health", HTTP_GET, []() {
    String body = "{\"status\":\"ok\",\"hasTelemetry\":";
    body += hasTelemetry ? "true" : "false";
    body += ",\"wsPath\":\"/telemetry\",\"wsPort\":";
    body += String(WS_PORT);
    body += "}";
    httpServer.send(200, "application/json", body);
  });

  httpServer.on("/telemetry", HTTP_GET, []() {
    httpServer.send(200, "application/json", latestJson);
  });

  httpServer.onNotFound([]() {
    httpServer.send(200, "text/plain",
                    "Ground station ready. WebSocket endpoint: ws://192.168.4.1:8765");
  });

  wsServer.begin();
  wsServer.onEvent(onWsEvent);
  httpServer.begin();
}

// New ESP-NOW receive callback
void OnDataRecv(const esp_now_recv_info_t *recv_info, const uint8_t *incomingData, int len) {
  if (len == sizeof(myData)) {
    memcpy(&myData, incomingData, sizeof(myData));

    // Get MAC address from recv_info
    char macStr[18];
    snprintf(macStr, sizeof(macStr),
             "%02X:%02X:%02X:%02X:%02X:%02X",
             recv_info->src_addr[0], recv_info->src_addr[1], recv_info->src_addr[2],
             recv_info->src_addr[3], recv_info->src_addr[4], recv_info->src_addr[5]);

    // Send Data to Matlab/Serial
    Serial.write((uint8_t*)&myData, sizeof(myData));
    hasTelemetry = true;
    telemetryDirty = true;

    // Optional: Print debug information
    /*
    Serial.print("From MAC: ");
    Serial.println(macStr);
    
    Serial.print("Header: "); Serial.println(myData.Header);
    Serial.print("Timestamp: "); Serial.println(myData.timestamp);
    
    Serial.print("Orientation - Roll: "); Serial.print(myData.roll);
    Serial.print(", Pitch: "); Serial.print(myData.pitch);
    Serial.print(", Yaw: "); Serial.println(myData.yaw);
    
    Serial.print("Acceleration - X: "); Serial.print(myData.Xacc);
    Serial.print(", Y: "); Serial.print(myData.Yacc);
    Serial.print(", Z: "); Serial.println(myData.Zacc);
    
    Serial.print("Gyro - X: "); Serial.print(myData.Angaccx);
    Serial.print(", Y: "); Serial.print(myData.Angaccy);
    Serial.print(", Z: "); Serial.println(myData.Angaccz);
    
    Serial.print("Magnetometer - X: "); Serial.print(myData.Magx);
    Serial.print(", Y: "); Serial.print(myData.Magy);
    Serial.print(", Z: "); Serial.println(myData.Magz);
    
    Serial.print("Environment - Temp: "); Serial.print(myData.Temperature);
    Serial.print("°C, Alt: "); Serial.print(myData.Altitude);
    Serial.print("m, Pressure: "); Serial.println(myData.Pressure);
    
    Serial.print("Compass Heading: "); Serial.print(myData.CompassHeading);
    Serial.print("°, GPS Heading: "); Serial.println(myData.GPSHeading);
    
    Serial.print("GPS - Sat: "); Serial.print(myData.Sat);
    Serial.print(", Lat: "); Serial.print(myData.Lat, 6);
    Serial.print(", Lon: "); Serial.print(myData.Long, 6);
    Serial.print(", GPS Alt: "); Serial.println(myData.GPSAlt);
    
    Serial.print("Distance - Current: "); Serial.print(myData.Distance);
    Serial.print("m, Total: "); Serial.print(myData.TotalDistance);
    Serial.println("m");
    Serial.println("----------------------");
    */
  } else {
    Serial.print("Invalid data length: ");
    Serial.println(len);
  }
}

void setup() {
  Serial.begin(115200);
  delay(300);

  WiFi.onEvent(onWiFiEvent);

  prepareWiFiRadio();

  // Espressif ESP-NOW + SoftAP examples start the AP first, then esp_now_init().
  if (!startSoftAccessPoint()) {
    Serial.println("FATAL: Soft AP did not start — fix Wi-Fi before using the app.");
    return;
  }

#if GS_ENABLE_ESPNOW
  if (esp_now_init() != ESP_OK) {
    Serial.println("Error initializing ESP-NOW (continuing; HTTP/WebSocket still work).");
  } else {
    esp_now_register_recv_cb(OnDataRecv);
    Serial.println("ESP-NOW receive callback registered.");
  }
#else
  Serial.println("GS_ENABLE_ESPNOW=0: ESP-NOW disabled (AP + HTTP/WebSocket only).");
#endif

  configureWebEndpoints();

  Serial.println("Receiver ready with updated data structure...");

  // Optional: Test data transmission (uncomment to test)
  /*
  myData.Header = 2864434397;
  myData.timestamp = millis();
  myData.Xacc = 1.0;
  myData.Yacc = 2.0;
  myData.Zacc = 3.0;
  myData.Angaccx = 4.0;
  myData.Angaccy = 5.0;
  myData.Angaccz = 6.0;
  myData.roll = 10.5;
  myData.pitch = -5.2;
  myData.yaw = 45.7;
  myData.Magx = 11.0;
  myData.Magy = 12.0;
  myData.Magz = 13.0;
  myData.Temperature = 25.5;
  myData.Altitude = 217.0;
  myData.Pressure = 101325.0;
  myData.CompassHeading = 90.0;
  myData.GPSHeading = 95.2;
  myData.Sat = 8.0;
  myData.Lat = 31.5204;
  myData.Long = 74.3587;
  myData.GPSAlt = 218.5;
  myData.Distance = 15.3;
  myData.TotalDistance = 1250.7;

  while(1) {
    Serial.write((uint8_t*)&myData, sizeof(myData));
    delay(1000);
  }
  */
}

void loop() {
  wsServer.loop();
  httpServer.handleClient();

  if (telemetryDirty) {
    telemetryDirty = false;
    latestJson = buildTelemetryJson(myData);
    wsServer.broadcastTXT(latestJson);
  }
  
  // Optional: Periodic status message
  static unsigned long lastStatus = 0;
  if (millis() - lastStatus > 10000) { // Every 10 seconds
    Serial.print("GS alive | AP IP: ");
    Serial.print(WiFi.softAPIP());
    Serial.print(" | stations: ");
    Serial.print(WiFi.softAPgetStationNum());
#if GS_ENABLE_ESPNOW
    Serial.println(" | waiting for ESP-NOW...");
#else
    Serial.println(" | ESP-NOW off (GS_ENABLE_ESPNOW=0).");
#endif
    lastStatus = millis();
  }
  
  delay(100);
}