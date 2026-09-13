/*
  gs_ble.h — BLE GATT server the Flutter app actually speaks.

  What changed vs the base Ground_Station_Code.ino
  ------------------------------------------------
  The base sketch advertised as "APEXech-GS" with private 7d7e1000-… UUIDs and
  exposed no writable characteristic. The app (lib/view_model/view_model.dart)
  looks for the Nordic UART Service, filters scan results on the name
  "CanSat", reconnects with the exact name "CanSat-GS", and pairs by WRITING
  "PAIR:<6 digits>" — so with the base UUIDs it could never discover, pair, or
  receive anything. This file implements the contract the app expects.

  Handshake
  ---------
    app  -> connect, subscribe to TX (notify)
    GS   -> {"pair":"required"}
    app  -> write "PAIR:123456" to RX
    GS   -> {"pair":"ok"}  (or {"pair":"fail"})
    GS   -> flat telemetry JSON at up to 20 Hz, camera slices on CAM TX

  Threading rule: notify() is only ever called from loop(). Notifying from an
  ESP-NOW callback or from inside a NimBLE callback corrupts the NimBLE heap.
*/

#ifndef GS_BLE_H
#define GS_BLE_H

#include "gs_config.h"

#if GS_ENABLE_BLE

#include <NimBLEDevice.h>

#include "gs_camera.h"
#include "gs_telemetry.h"

static NimBLEServer         *gsBleServer  = nullptr;
static NimBLECharacteristic *gsBleTelemTx = nullptr;
static NimBLECharacteristic *gsBleRx      = nullptr;
#if GS_ENABLE_CAMERA
static NimBLECharacteristic *gsBleCamTx = nullptr;
#endif

static volatile bool gsBleConnected = false;
static uint32_t gsBleNotifyCount = 0;
static uint32_t gsBleCamFramesOut = 0;

static char gsBleJsonBuf[GS_JSON_BUF_SIZE];

// NimBLE 2.x does not advertise the name or a scan response by default. A
// 128-bit service UUID plus a name does not fit in the 31-byte advertisement,
// so without a scan response the app sees an unnamed device and its
// name filter ("CanSat") rejects it.
static bool gsBleStartAdvertising() {
  NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
  adv->stop();
  adv->clearData();
  adv->enableScanResponse(true);
  adv->addServiceUUID(GS_BLE_NUS_SERVICE_UUID);
#if GS_ENABLE_CAMERA
  // Web Bluetooth can only reach services listed here, because the app calls
  // startScan(withServices: [nus, cam]) on web.
  adv->addServiceUUID(GS_BLE_CAM_SERVICE_UUID);
#endif
  adv->setName(GS_BLE_NAME);
  adv->setMinInterval(32);
  adv->setMaxInterval(64);

  const bool ok = adv->start();
  if (!ok) Serial.println("[BLE] ERROR: advertising failed to start");
  return ok;
}

static void gsBleEnsureAdvertising() {
  if (gsBleConnected) return;
  NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
  if (adv && !adv->isAdvertising()) {
    Serial.println("[BLE] Advertising stopped — restarting");
    gsBleStartAdvertising();
  }
}

/// Send {"pair":"ok"|"fail"|"required"}. The app matches on these exact
/// strings and treats any short {"pair":…} frame as non-telemetry.
static void gsBleNotifyPair(const char *result) {
  if (!gsBleTelemTx || !gsBleConnected) return;
  char msg[24];
  const int n = snprintf(msg, sizeof(msg), "{\"pair\":\"%s\"}", result);
  if (n <= 0) return;
  gsBleTelemTx->setValue((uint8_t *)msg, (size_t)n);
  gsBleTelemTx->notify();
}

class GsBleServerCallbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer * /*server*/, NimBLEConnInfo & /*info*/) override {
    gsBleConnected = true;
    gsPaired = false;
    Serial.println("[BLE] Client connected — waiting for pairing code.");
    gsBleNotifyPair("required");
  }

  void onDisconnect(NimBLEServer * /*server*/, NimBLEConnInfo & /*info*/,
                    int /*reason*/) override {
    const bool wasPaired = gsPaired;
    gsBleConnected = false;
    gsPaired = false;

#if GS_ROTATE_PAIR_CODE
    if (wasPaired) {
      gsGeneratePairCode();
    } else {
      Serial.println("[BLE] Disconnected before pairing — same code still valid.");
    }
#else
    (void)wasPaired;
    Serial.println("[BLE] Disconnected — same code still valid.");
#endif

    gsBleStartAdvertising();
  }
};

class GsBleRxCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic *c, NimBLEConnInfo & /*info*/) override {
    std::string v = c->getValue();

    // "PAIR:" + 6 digits = 11 bytes.
    if (v.size() < 11 || v.compare(0, 5, "PAIR:") != 0) return;

    if (gsCheckPairCode(v.c_str() + 5, 6)) {
      gsPaired = true;
      gsBleNotifyPair("ok");
      Serial.println("[PAIR] BLE OK — telemetry starts from loop()");
      gsTelemetryDirty = true;
    } else {
      gsPaired = false;
      gsBleNotifyPair("fail");
      Serial.println("[PAIR] BLE FAIL — wrong code");
    }
  }
};


static void gsBleSetup() {
  NimBLEDevice::init(GS_BLE_NAME);
  NimBLEDevice::setMTU(GS_BLE_MTU);
  NimBLEDevice::setPower(GS_BLE_TX_POWER);

  gsBleServer = NimBLEDevice::createServer();
  gsBleServer->setCallbacks(new GsBleServerCallbacks());

  NimBLEService *nus = gsBleServer->createService(GS_BLE_NUS_SERVICE_UUID);
  gsBleTelemTx = nus->createCharacteristic(GS_BLE_NUS_TX_UUID,
                                           NIMBLE_PROPERTY::NOTIFY |
                                           NIMBLE_PROPERTY::READ);
  gsBleRx = nus->createCharacteristic(GS_BLE_NUS_RX_UUID,
                                      NIMBLE_PROPERTY::WRITE |
                                      NIMBLE_PROPERTY::WRITE_NR);
  gsBleRx->setCallbacks(new GsBleRxCallbacks());
  gsBleTelemTx->setValue("{\"pair\":\"required\"}");
  nus->start();

#if GS_ENABLE_CAMERA
  NimBLEService *cam = gsBleServer->createService(GS_BLE_CAM_SERVICE_UUID);
  gsBleCamTx = cam->createCharacteristic(GS_BLE_CAM_TX_UUID,
                                         NIMBLE_PROPERTY::NOTIFY |
                                         NIMBLE_PROPERTY::READ);
  cam->start();
#endif

  if (!gsBleStartAdvertising()) {
    Serial.println("[BLE] WARNING: not advertising — check NimBLE-Arduino version");
  } else {
    Serial.printf("[BLE] Advertising as \"%s\"\n", GS_BLE_NAME);
  }
}

/// Push one telemetry frame. Call from loop() only.
static void gsBlePushTelemetry() {
  if (!gsBleTelemTx || !gsBleConnected || !gsPaired) return;

  // Send each ESP-NOW packet once; the rate cap thins that to 20 Hz. Returning
  // early leaves lastCount untouched so a capped packet goes out next pass.
  static uint32_t lastCount = 0;
  const uint32_t count = gsPacketCount;
  if (count == lastCount) return;

  static uint32_t lastMs = 0;
  static uint32_t lastLogMs = 0;
  const uint32_t now = millis();
  if (lastMs != 0 && (now - lastMs) < GS_TELEM_MIN_INTERVAL_MS) return;

  struct_message snapshot;
  if (!gsCopyTelemetry(snapshot)) return;

  const size_t n = gsBuildTelemetryJson(snapshot, gsBleJsonBuf, sizeof(gsBleJsonBuf));
  if (n == 0) {
    Serial.println("[BLE] telemetry JSON did not fit GS_JSON_BUF_SIZE");
    return;
  }

  lastMs = now;
  lastCount = count;
  gsBleTelemTx->setValue((uint8_t *)gsBleJsonBuf, n);
  gsBleTelemTx->notify();
  gsBleNotifyCount++;

  if (now - lastLogMs >= 2000) {
    lastLogMs = now;
    Serial.printf("[BLE] notify %u B | temp=%.1f roll=%.3f yaw=%.1f sat=%.0f\n",
                  (unsigned)n, snapshot.Temperature, snapshot.roll,
                  snapshot.yaw, snapshot.Sat);
  }
}

#if GS_ENABLE_CAMERA
/// Slice the latest JPEG into notifies: 6-byte big-endian header
/// [frameId hi, frameId lo, packetId hi, packetId lo, total hi, total lo]
/// followed by up to GS_BLE_CAM_PAYLOAD bytes. Matches
/// ViewModel._processCamNotifyLegacy in the Flutter app.
static void gsBlePushCameraFrame() {
  if (!gsBleCamTx || !gsBleConnected || !gsPaired) return;

  static uint32_t lastSeq = 0;
  const uint32_t seq = gsCamFrameSeq;
  if (seq == lastSeq) return;

  gsCamReaderBusy = true;
  const size_t   jpgLen  = gsCamJpegLen;
  const uint16_t frameId = gsCamFrameId;

  if (jpgLen < 4 || jpgLen > GS_CAM_MAX_FRAME) {
    gsCamReaderBusy = false;
    return;
  }
  lastSeq = seq;

  const uint16_t totalChunks =
      (uint16_t)((jpgLen + GS_BLE_CAM_PAYLOAD - 1) / GS_BLE_CAM_PAYLOAD);
  static uint8_t buf[6 + GS_BLE_CAM_PAYLOAD];

  for (uint16_t i = 0; i < totalChunks; i++) {
    const uint32_t offset = (uint32_t)i * GS_BLE_CAM_PAYLOAD;
    const uint16_t chunkSize =
        (uint16_t)min((uint32_t)GS_BLE_CAM_PAYLOAD, (uint32_t)(jpgLen - offset));

    buf[0] = (uint8_t)(frameId >> 8);
    buf[1] = (uint8_t)(frameId & 0xFF);
    buf[2] = (uint8_t)(i >> 8);
    buf[3] = (uint8_t)(i & 0xFF);
    buf[4] = (uint8_t)(totalChunks >> 8);
    buf[5] = (uint8_t)(totalChunks & 0xFF);
    memcpy(buf + 6, gsCamJpeg + offset, chunkSize);

    gsBleCamTx->setValue(buf, 6 + chunkSize);
    gsBleCamTx->notify();
    delay(2);  // let the controller drain; without it notifies are dropped
  }
  gsCamReaderBusy = false;

  gsBleCamFramesOut++;
  static uint32_t lastCamLog = 0;
  if (millis() - lastCamLog >= 3000) {
    lastCamLog = millis();
    Serial.printf("[CAM] BLE frame %u (%u B, %u chunks) total=%lu\n",
                  frameId, (unsigned)jpgLen, totalChunks,
                  (unsigned long)gsBleCamFramesOut);
  }
}
#else
static inline void gsBlePushCameraFrame() {}
#endif  // GS_ENABLE_CAMERA

#else  // !GS_ENABLE_BLE

static const bool gsBleConnected = false;
static const uint32_t gsBleNotifyCount = 0;
static inline void gsBleSetup() {}
static inline void gsBleEnsureAdvertising() {}
static inline void gsBlePushTelemetry() {}
static inline void gsBlePushCameraFrame() {}

#endif  // GS_ENABLE_BLE
#endif  // GS_BLE_H
