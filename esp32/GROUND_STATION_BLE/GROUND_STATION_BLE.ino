/*
 * CanSat Ground Station — BLE (NimBLE) + ESP-NOW
 *
 * FLASH SIZE: Uses NimBLE (not the built-in "BLE" library). Install:
 *   Library Manager → "NimBLE-Arduino" by h2zero
 *
 * If you still get "Sketch too big", set:
 *   Tools → Partition Scheme → "Huge APP (3MB No OTA)"
 *
 * Optional camera over BLE (adds flash/RAM): set GS_ENABLE_BLE_CAMERA to 1
 *
 * Pairing: 6-digit code on Serial — student enters in Flutter app.
 */

#include <NimBLEDevice.h>
#include <WiFi.h>
#include <esp_now.h>
#include <esp_mac.h>
#include <esp_wifi.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

#define NUS_SERVICE_UUID "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define NUS_TX_UUID "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
#define NUS_RX_UUID "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"

#define CAM_SERVICE_UUID "6E400010-B5A3-F393-E0A9-E50E24DCCA9E"
#define CAM_TX_UUID "6E400011-B5A3-F393-E0A9-E50E24DCCA9E"

// Set to 0 when using real CanSat ESP-NOW telemetry.
#ifndef GS_SEND_SAMPLE_DATA
#define GS_SEND_SAMPLE_DATA 0
#endif

// 1 = forward ESP32-CAM JPEG over BLE (set Tools → Partition Scheme → Huge APP).
// 0 = telemetry only (fits default partition).
#ifndef GS_ENABLE_BLE_CAMERA
#define GS_ENABLE_BLE_CAMERA 1
#endif

typedef struct struct_message
{
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

// Old CANSAT.ino layout (64 bytes) — still on many flight boards.
typedef struct legacy_struct_message
{
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

typedef struct __attribute__((packed))
{
  uint16_t frame_id;
  uint16_t packet_id;
  uint16_t total_packets;
  uint16_t size;
  uint8_t data[180];
} CamPacket;

#define CAM_PACKET_LEN 188

// Set 1 to send a tiny test JPEG over BLE every 4s (no ESP32-CAM needed).
#ifndef GS_TEST_BLE_CAMERA
#define GS_TEST_BLE_CAMERA 0
#endif

struct_message myData;
volatile bool telemetryDirty = false;

#if GS_ENABLE_BLE_CAMERA
// Same reassembly as Rx_wroom_tft_code.ino (30 KB max JPEG)
#define MAX_JPEG_SIZE 30000
static uint8_t jpgBuffer[MAX_JPEG_SIZE];
static uint32_t jpgWriteIdx = 0;
static uint16_t camFrameId = 0xFFFF;
volatile bool camFrameReady = false;
volatile bool camBleBusy = false;
static uint32_t camEspNowPackets = 0;
static uint32_t camFramesForwarded = 0;
#endif

static NimBLEServer *pServer = nullptr;
static NimBLECharacteristic *pTelemTx = nullptr;
#if GS_ENABLE_BLE_CAMERA
static NimBLECharacteristic *pCamTx = nullptr;
#endif

static bool deviceConnected = false;
static bool oldConnected = false;

char pairCode[7] = "000000";

// NimBLE 2.x: name/TX power are not advertised by default; scan response is off
// by default. Without scan response, a 128-bit service UUID + name may not fit in
// the 31-byte adv packet — phones/laptops then see no "CanSat-GS" name.
static bool startBleAdvertising()
{
  NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
  adv->stop();
  adv->clearData();
  adv->enableScanResponse(true);
  adv->addServiceUUID(NUS_SERVICE_UUID);
#if GS_ENABLE_BLE_CAMERA
  adv->addServiceUUID(CAM_SERVICE_UUID);
#endif
  adv->setName("CanSat-GS");
  adv->setMinInterval(32);
  adv->setMaxInterval(64);
  const bool ok = adv->start();
  if (!ok)
  {
    Serial.println("[BLE] ERROR: advertising failed to start");
  }
  return ok;
}

static void ensureBleAdvertising()
{
  if (deviceConnected)
    return;
  NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
  if (adv && !adv->isAdvertising())
  {
    Serial.println("[BLE] Advertising stopped — restarting");
    startBleAdvertising();
  }
}
bool clientPaired = false;

static char jsonBuf[640];

size_t buildTelemetryJson(const struct_message &d, char *out, size_t outLen);

static void importLegacyTelemetry(const legacy_struct_message &leg)
{
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
  myData.roll = 0.0f;
  myData.pitch = 0.0f;
  myData.yaw = 0.0f;
  myData.Distance = 0.0f;
  myData.TotalDistance = 0.0f;
}

// BLE notify ONLY from loop() — never from ESP-NOW or NimBLE callbacks (heap crash).
static void pushTelemetryBle()
{
  if (!telemetryDirty || !deviceConnected || !clientPaired || !pTelemTx)
    return;

  static uint32_t lastTelemMs = 0;
  static uint32_t lastTelemLogMs = 0;
  const uint32_t now = millis();
  if (lastTelemMs != 0 && (now - lastTelemMs) < 50)
    return; // max ~20 Hz
  lastTelemMs = now;

  const size_t n = buildTelemetryJson(myData, jsonBuf, sizeof(jsonBuf));
  if (n == 0 || n >= sizeof(jsonBuf))
  {
    Serial.printf("[TELEM] JSON too large (%u bytes, max %u)\n", (unsigned)n,
                  (unsigned)sizeof(jsonBuf) - 1);
    return;
  }

  pTelemTx->setValue((uint8_t *)jsonBuf, n);
  pTelemTx->notify();
  telemetryDirty = false;

  if (now - lastTelemLogMs >= 3000)
  {
    lastTelemLogMs = now;
    Serial.printf("[TELEM] BLE notify %u bytes temp=%.1f paired=%s\n",
                  (unsigned)n, myData.Temperature, clientPaired ? "yes" : "no");
  }
}

static void printWifiStaMac()
{
  uint8_t mac[6];
  esp_read_mac(mac, ESP_MAC_WIFI_STA);
  Serial.printf("[BOOT] MAC (use in Tx_camera receiverMAC): %02X:%02X:%02X:%02X:%02X:%02X\n",
                mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
}

// Call right after Serial.begin — helps USB-CDC boards and confirms the port works.
static void serialBootBanner()
{
  delay(500);
#if ARDUINO_USB_CDC_ON_BOOT
  unsigned long t0 = millis();
  while (!Serial && (millis() - t0) < 4000)
  {
    delay(10);
  }
#endif
  Serial.println();
  Serial.println("========================================");
  Serial.println("  CanSat Ground Station (BLE / NimBLE)");
  Serial.println("  Baud: 115200 — open monitor, then RESET");
  Serial.println("========================================");
  Serial.flush();
}

void regeneratePairCode()
{
  uint32_t n = esp_random() % 1000000UL;
  snprintf(pairCode, sizeof(pairCode), "%06lu", (unsigned long)n);
  clientPaired = false;
  Serial.printf("\n*** PAIRING CODE: %s ***\n\n", pairCode);
}

void notifyPairResult(const char *result)
{
  if (!pTelemTx || !deviceConnected)
    return;
  char msg[24];
  snprintf(msg, sizeof(msg), "{\"pair\":\"%s\"}", result);
  pTelemTx->setValue((uint8_t *)msg, strlen(msg));
  pTelemTx->notify();
}

#if GS_ENABLE_BLE_CAMERA
static void resetCamFrame() { jpgWriteIdx = 0; }
#endif

size_t buildTelemetryJson(const struct_message &d, char *out, size_t outLen)
{
  return snprintf(
      out, outLen,
      "{\"temp\":%.4f,\"alt\":%.4f,\"press\":%.4f,\"seaPress\":%.4f,"
      "\"head\":%.4f,\"ax\":%.4f,\"ay\":%.4f,\"az\":%.4f,"
      "\"gx\":%.4f,\"gy\":%.4f,\"gz\":%.4f,"
      "\"roll\":%.6f,\"pitch\":%.6f,\"yaw\":%.6f,"
      "\"mx\":%.4f,\"my\":%.4f,\"mz\":%.4f,"
      "\"sat\":%.0f,\"lat\":%.6f,\"lon\":%.6f,\"gpsAlt\":%.4f,\"ts\":%lu}",
      d.Temperature, d.Altitude, d.Pressure, d.Pressure, d.CompassHeading,
      d.Xacc, d.Yacc, d.Zacc, d.Angaccx, d.Angaccy, d.Angaccz,
      d.roll, d.pitch, d.yaw, d.Magx, d.Magy, d.Magz,
      d.Sat, d.Lat, d.Long, d.GPSAlt, d.timestamp);
}

void OnDataRecv(const esp_now_recv_info_t *info, const uint8_t *data, int len)
{
  (void)info;

#if GS_ENABLE_BLE_CAMERA
  // Camera packets first — must match Tx_camera_code Packet (188 bytes packed).
  if (len == CAM_PACKET_LEN || len == (int)sizeof(CamPacket))
  {
    camEspNowPackets++;
    static bool loggedFirstCam = false;
    if (!loggedFirstCam) {
      loggedFirstCam = true;
      Serial.println("[CAM] ESP-NOW camera packets arriving");
    }
    CamPacket pkt;
    memcpy(&pkt, data, sizeof(pkt));
    if (pkt.packet_id == 0)
    {
      resetCamFrame();
      camFrameId = pkt.frame_id;
    }
    if (pkt.frame_id != camFrameId)
      return;
    if (pkt.size > 0 && pkt.size <= 180 &&
        jpgWriteIdx + pkt.size <= MAX_JPEG_SIZE)
    {
      memcpy(jpgBuffer + jpgWriteIdx, pkt.data, pkt.size);
      jpgWriteIdx += pkt.size;
    }
    if (pkt.packet_id == pkt.total_packets - 1 && pkt.total_packets > 0)
    {
      camFrameReady = true;
    }
    return;
  }
#endif

  if (len == sizeof(struct_message))
  {
    memcpy(&myData, data, sizeof(myData));
    telemetryDirty = true;
    return;
  }

  if (len == sizeof(legacy_struct_message))
  {
    legacy_struct_message leg;
    memcpy(&leg, data, sizeof(leg));
    importLegacyTelemetry(leg);
    telemetryDirty = true;
    return;
  }

  static uint32_t lastLenLog = 0;
  if (millis() - lastLenLog >= 5000)
  {
    lastLenLog = millis();
    Serial.printf("[ESP-NOW] ignored len=%d (telemetry=%u legacy=%u", len,
                  (unsigned)sizeof(struct_message),
                  (unsigned)sizeof(legacy_struct_message));
#if GS_ENABLE_BLE_CAMERA
    Serial.printf(", camera=%u", (unsigned)sizeof(CamPacket));
#endif
    Serial.println(")");
  }
}

class ServerCallbacks : public NimBLEServerCallbacks
{
  void onConnect(NimBLEServer * /*server*/, NimBLEConnInfo & /*connInfo*/) override
  {
    deviceConnected = true;
    clientPaired = false;
    Serial.println("[BLE] Connected — enter pairing code in app.");
    notifyPairResult("required");
  }

  void onDisconnect(NimBLEServer * /*server*/, NimBLEConnInfo & /*connInfo*/, int /*reason*/) override
  {
    const bool wasPaired = clientPaired;
    deviceConnected = false;
    clientPaired = false;
    // Keep the same code when a client disconnects before pairing (common on
    // Windows WinRT). Only rotate after a successful paired session ends.
    if (wasPaired)
    {
      regeneratePairCode();
    }
    else
    {
      Serial.println("[BLE] Disconnected — pairing code unchanged (retry with same code).");
    }
    startBleAdvertising();
    Serial.println("[BLE] Disconnected.");
  }
};

class RxCallbacks : public NimBLECharacteristicCallbacks
{
  void onWrite(NimBLECharacteristic *c, NimBLEConnInfo & /*connInfo*/) override
  {
    std::string v = c->getValue();
    if (v.size() < 11 || v.compare(0, 5, "PAIR:") != 0)
      return;

    if (strncmp(v.c_str() + 5, pairCode, 6) == 0)
    {
      clientPaired = true;
      notifyPairResult("ok");
      Serial.println("[PAIR] OK — telemetry starts from main loop");
      telemetryDirty = true;
    }
    else
    {
      clientPaired = false;
      notifyPairResult("fail");
      Serial.println("[PAIR] FAIL");
    }
  }
};

#if GS_ENABLE_BLE_CAMERA
// Fits ATT MTU 517 (3 byte header + 244 payload + 6 meta = 253 per notify).
#define CAM_BLE_PAYLOAD 244

void sendCameraFrame(uint16_t frameId, const uint8_t *jpg, uint32_t jpgLen)
{
  if (!deviceConnected || !clientPaired || !pCamTx || camBleBusy)
    return;
  if (jpgLen < 4)
    return;

  camBleBusy = true;
  const uint16_t totalChunks =
      (uint16_t)((jpgLen + CAM_BLE_PAYLOAD - 1) / CAM_BLE_PAYLOAD);
  static uint8_t buf[6 + CAM_BLE_PAYLOAD];

  for (uint16_t i = 0; i < totalChunks; i++)
  {
    const uint32_t offset = (uint32_t)i * CAM_BLE_PAYLOAD;
    const uint16_t chunkSize =
        (uint16_t)min((uint32_t)CAM_BLE_PAYLOAD, jpgLen - offset);

    buf[0] = (uint8_t)(frameId >> 8);
    buf[1] = (uint8_t)(frameId & 0xFF);
    buf[2] = (uint8_t)(i >> 8);
    buf[3] = (uint8_t)(i & 0xFF);
    buf[4] = (uint8_t)(totalChunks >> 8);
    buf[5] = (uint8_t)(totalChunks & 0xFF);
    memcpy(buf + 6, jpg + offset, chunkSize);

    pCamTx->setValue(buf, 6 + chunkSize);
    pCamTx->notify();
    delay(2);
  }
  camBleBusy = false;

  camFramesForwarded++;
  static uint32_t lastCamLog = 0;
  if (millis() - lastCamLog >= 3000)
  {
    lastCamLog = millis();
    Serial.printf("[CAM] BLE sent frame %u (%u bytes, %u chunks) total=%lu\n",
                  frameId, jpgLen, totalChunks,
                  (unsigned long)camFramesForwarded);
  }
}

#if GS_TEST_BLE_CAMERA
// Minimal valid 1×1 JPEG — proves phone BLE camera path without ESP32-CAM.
static const uint8_t kTestJpeg[] = {
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
    0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
    0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
    0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
    0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
    0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
    0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
    0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
    0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x14, 0x00, 0x01,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x08, 0xFF, 0xC4, 0x00, 0x14, 0x10, 0x01, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00,
    0x7F, 0xA0, 0xFF, 0xD9};
static const size_t kTestJpegLen = sizeof(kTestJpeg);

static void sendTestCameraFrame()
{
  static uint16_t testFrameId = 0;
  sendCameraFrame(testFrameId++, kTestJpeg, kTestJpegLen);
}
#endif
#endif

void setup()
{
  Serial.begin(115200);
  serialBootBanner();

  Serial.printf("[BOOT] Free heap: %u bytes\n", ESP.getFreeHeap());
  Serial.printf("[BOOT] BLE camera: %s\n",
                GS_ENABLE_BLE_CAMERA ? "ON" : "OFF");
#if GS_ENABLE_BLE_CAMERA
  Serial.println("[BOOT] Camera ON → use Partition Scheme: Huge APP (3MB No OTA)");
  Serial.printf("[BOOT] GS_TEST_BLE_CAMERA=%d (1=sends test JPEG every 4s)\n",
                GS_TEST_BLE_CAMERA);
#endif

  // BLE before WiFi/ESP-NOW improves radio coexistence on ESP32.
  NimBLEDevice::init("CanSat-GS");
#if defined(NIMBLE_VERSION)
  Serial.printf("[BOOT] NimBLE lib: %s\n", NIMBLE_VERSION);
#endif
  // Phone requests MTU 512; match it so full JSON fits in one notify.
  NimBLEDevice::setMTU(517);
  NimBLEDevice::setPower(9);

  pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  NimBLEService *nus = pServer->createService(NUS_SERVICE_UUID);
  pTelemTx = nus->createCharacteristic(NUS_TX_UUID, NIMBLE_PROPERTY::NOTIFY);
  NimBLECharacteristic *rx = nus->createCharacteristic(
      NUS_RX_UUID, NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR);
  rx->setCallbacks(new RxCallbacks());
  nus->start();

#if GS_ENABLE_BLE_CAMERA
  NimBLEService *cam = pServer->createService(CAM_SERVICE_UUID);
  pCamTx = cam->createCharacteristic(
      CAM_TX_UUID, NIMBLE_PROPERTY::NOTIFY | NIMBLE_PROPERTY::READ);
  cam->start();
  Serial.printf("[BOOT] CamPacket size=%u (expect %u)\n",
                (unsigned)sizeof(CamPacket), (unsigned)CAM_PACKET_LEN);
#endif

  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  esp_wifi_set_channel(1, WIFI_SECOND_CHAN_NONE);
  printWifiStaMac();

  if (esp_now_init() != ESP_OK)
  {
    Serial.println("ESP-NOW init failed");
  }
  else
  {
    esp_now_register_recv_cb(OnDataRecv);
  }

  if (!startBleAdvertising())
  {
    Serial.println("[BOOT] WARNING: BLE not advertising — check NimBLE-Arduino version");
  }

  regeneratePairCode();
  Serial.printf("[BOOT] ESP-NOW telemetry sizes: new=%u legacy=%u\n",
                (unsigned)sizeof(struct_message),
                (unsigned)sizeof(legacy_struct_message));
  Serial.println("[BOOT] NimBLE ready — advertising as CanSat-GS");
  Serial.flush();
}

void loop()
{
  static uint32_t lastHeartbeat = 0;
  if (millis() - lastHeartbeat >= 5000)
  {
    lastHeartbeat = millis();
    NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
    Serial.printf(
        "[alive] heap=%u BLE=%s paired=%s telem=%s"
#if GS_ENABLE_BLE_CAMERA
        " cam_espnow=%lu cam_ble=%lu"
#endif
        "\n",
        ESP.getFreeHeap(), deviceConnected ? "connected" : "idle",
        clientPaired ? "yes" : "no", telemetryDirty ? "pending" : "idle"
#if GS_ENABLE_BLE_CAMERA
        ,
        (unsigned long)camEspNowPackets, (unsigned long)camFramesForwarded
#endif
    );
  }
  ensureBleAdvertising();
  if (!deviceConnected && oldConnected)
  {
    oldConnected = false;
    startBleAdvertising();
  }
  if (deviceConnected && !oldConnected)
  {
    oldConnected = true;
  }

#if GS_SEND_SAMPLE_DATA
  {
    static uint32_t lastMs = 0;
    static uint32_t cnt = 0;
    if (millis() - lastMs >= 100)
    {
      lastMs = millis();
      float t = ++cnt * 0.1f;
      myData.timestamp = millis();
      myData.roll = sinf(t * 0.8f) * 0.52f;
      myData.pitch = cosf(t * 0.6f) * 0.35f;
      myData.yaw = fmodf(t * 28.6f, 360.0f);
      myData.Zacc = 9.81f;
      myData.Temperature = 24.5f;
      telemetryDirty = true;
    }
  }
#endif

  pushTelemetryBle();

#if GS_ENABLE_BLE_CAMERA
  if (camFrameReady && deviceConnected && clientPaired && !camBleBusy)
  {
    camFrameReady = false;
    const uint32_t len = jpgWriteIdx;
    if (len > 2 && jpgBuffer[0] == 0xFF && jpgBuffer[1] == 0xD8)
    {
      sendCameraFrame(camFrameId, jpgBuffer, len);
    }
    else if (len > 0)
    {
      Serial.println("[CAM] Corrupt JPEG skipped");
    }
    resetCamFrame();
  }

#if GS_TEST_BLE_CAMERA
  {
    static uint32_t lastTestMs = 0;
    if (deviceConnected && clientPaired && !camBleBusy &&
        millis() - lastTestMs >= 4000)
    {
      lastTestMs = millis();
      sendTestCameraFrame();
    }
  }
#endif
#endif

  delay(5);
}
