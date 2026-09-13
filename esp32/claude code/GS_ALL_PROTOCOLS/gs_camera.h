/*
  gs_camera.h — ESP32-CAM relay.

  The camera board (Camera working code/Tx_camera_code) slices each JPEG into
  188-byte ESP-NOW packets. This file reassembles them and republishes the
  frame two ways:

    Wi-Fi : multipart/x-mixed-replace MJPEG on port 81  -> mjpeg_stream widget
    BLE   : 6-byte big-endian header + 244-byte slice   -> ViewModel._onCameraChunk

  The original Ground_Station_Code.ino only reserved port 81 and answered 503,
  so the app's camera tab was permanently empty even with a camera attached.
*/

#ifndef GS_CAMERA_H
#define GS_CAMERA_H

#include <Arduino.h>
#include <WiFi.h>

#include "gs_config.h"

#if GS_ENABLE_CAMERA

// Wire format of one ESP-NOW camera packet. Must match Tx_camera_code.ino.
typedef struct __attribute__((packed)) {
  uint16_t frame_id;
  uint16_t packet_id;
  uint16_t total_packets;
  uint16_t size;
  uint8_t  data[180];
} GsCamPacket;

#define GS_CAM_PACKET_LEN 188
#define GS_CAM_SLICE      180

// ---- reassembly (written from the ESP-NOW callback) ------------------------
static uint8_t  gsCamAssembly[GS_CAM_MAX_FRAME];
static bool     gsCamGot[GS_CAM_MAX_PACKETS];
static uint16_t gsCamCurFrame = 0xFFFF;
static uint16_t gsCamTotal    = 0;
static uint16_t gsCamCount    = 0;
static size_t   gsCamAssembledLen = 0;

// ---- latest complete frame (read from loop()) ------------------------------
static uint8_t           gsCamJpeg[GS_CAM_MAX_FRAME];
static volatile size_t   gsCamJpegLen  = 0;
static volatile uint32_t gsCamFrameSeq = 0;
static volatile uint16_t gsCamFrameId  = 0;
static volatile uint32_t gsCamFramesIn = 0;

// Publishing a frame is a 20 kB memcpy from the Wi-Fi task while loop() may be
// streaming the same buffer. Rather than hold a spinlock for that long, the
// reader raises this flag and the writer drops the frame instead of tearing it.
static volatile bool gsCamReaderBusy = false;

WiFiServer gsCamServer(GS_CAM_PORT);
WiFiClient gsCamClients[GS_CAM_MAX_HTTP_CLIENTS];

/// Feed one ESP-NOW camera packet. Safe to call from the receive callback.
static void gsCamOnPacket(const GsCamPacket &p) {
  if (p.total_packets == 0 || p.total_packets > GS_CAM_MAX_PACKETS) return;
  if (p.packet_id >= p.total_packets || p.size > GS_CAM_SLICE) return;

  if (p.frame_id != gsCamCurFrame || p.total_packets != gsCamTotal) {
    gsCamCurFrame = p.frame_id;
    gsCamTotal = p.total_packets;
    gsCamCount = 0;
    gsCamAssembledLen = 0;
    memset(gsCamGot, 0, sizeof(gsCamGot));
  }

  const size_t off = (size_t)p.packet_id * GS_CAM_SLICE;
  if (off + p.size > GS_CAM_MAX_FRAME) return;

  if (!gsCamGot[p.packet_id]) {
    gsCamGot[p.packet_id] = true;
    gsCamCount++;
    memcpy(gsCamAssembly + off, p.data, p.size);
    if (p.packet_id == p.total_packets - 1) {
      gsCamAssembledLen = off + p.size;
    }
  }

  if (gsCamCount != gsCamTotal || gsCamAssembledLen < 4) return;

  const bool validJpeg = gsCamAssembly[0] == 0xFF && gsCamAssembly[1] == 0xD8 &&
                         gsCamAssembly[gsCamAssembledLen - 2] == 0xFF &&
                         gsCamAssembly[gsCamAssembledLen - 1] == 0xD9;
  if (!validJpeg) return;

  gsCamFramesIn++;
  if (gsCamReaderBusy) return;  // drop this frame rather than tear the buffer

  memcpy(gsCamJpeg, gsCamAssembly, gsCamAssembledLen);
  gsCamJpegLen = gsCamAssembledLen;
  gsCamFrameId = p.frame_id;
  gsCamFrameSeq = gsCamFrameSeq + 1;
}

// ============================================================
// MJPEG SERVER (port 81)
// ============================================================
// A raw WiFiServer is used instead of WebServer because multipart streaming
// needs the socket held open across many writes.
//
// Access-Control-Allow-Origin is required for Flutter Web: the browser treats
// http://<station-ip>:81 as a cross-origin fetch from the app's own origin.

static void gsCamBegin() {
  gsCamServer.begin();
  gsCamServer.setNoDelay(true);
}

static void gsCamAcceptClients(bool paired) {
  WiFiClient nc = gsCamServer.available();
  if (!nc) return;

  // Drain the request line/headers without blocking the loop.
  const uint32_t t0 = millis();
  while (nc.connected() && !nc.available() && millis() - t0 < 150) delay(1);
  while (nc.available()) nc.read();

  if (!paired) {
    nc.print("HTTP/1.1 403 Forbidden\r\n"
             "Access-Control-Allow-Origin: *\r\n"
             "Connection: close\r\n\r\n");
    nc.stop();
    return;
  }

  for (int i = 0; i < GS_CAM_MAX_HTTP_CLIENTS; i++) {
    if (!gsCamClients[i] || !gsCamClients[i].connected()) {
      gsCamClients[i].stop();
      gsCamClients[i] = nc;
      gsCamClients[i].print(
          "HTTP/1.1 200 OK\r\n"
          "Content-Type: multipart/x-mixed-replace; boundary=frame\r\n"
          "Access-Control-Allow-Origin: *\r\n"
          "Cache-Control: no-cache, no-store, must-revalidate\r\n"
          "Pragma: no-cache\r\n"
          "Connection: keep-alive\r\n\r\n");
      Serial.printf("[CAM] MJPEG viewer connected (slot %d)\n", i);
      return;
    }
  }

  nc.print("HTTP/1.1 503 Service Unavailable\r\n"
           "Access-Control-Allow-Origin: *\r\n"
           "Connection: close\r\n\r\n");
  nc.stop();
}

static void gsCamPushFrame() {
  static uint32_t lastSentSeq = 0;

  const uint32_t seq = gsCamFrameSeq;
  if (seq == lastSentSeq) return;

  bool anyViewer = false;
  for (int i = 0; i < GS_CAM_MAX_HTTP_CLIENTS; i++) {
    if (gsCamClients[i] && gsCamClients[i].connected()) {
      anyViewer = true;
      break;
    }
  }
  if (!anyViewer) return;

  gsCamReaderBusy = true;
  const size_t len = gsCamJpegLen;
  if (len > 0) {
    lastSentSeq = seq;
    for (int i = 0; i < GS_CAM_MAX_HTTP_CLIENTS; i++) {
      if (!gsCamClients[i] || !gsCamClients[i].connected()) continue;
      gsCamClients[i].printf(
          "--frame\r\nContent-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n",
          (unsigned)len);
      gsCamClients[i].write(gsCamJpeg, len);
      gsCamClients[i].print("\r\n");
    }
  }
  gsCamReaderBusy = false;
}

static void gsCamDropClients() {
  for (int i = 0; i < GS_CAM_MAX_HTTP_CLIENTS; i++) {
    if (gsCamClients[i]) gsCamClients[i].stop();
  }
}

#else  // !GS_ENABLE_CAMERA

#define GS_CAM_PACKET_LEN 188
static volatile size_t   gsCamJpegLen  = 0;
static volatile uint32_t gsCamFrameSeq = 0;
static volatile uint32_t gsCamFramesIn = 0;
static inline void gsCamBegin() {}
static inline void gsCamAcceptClients(bool) {}
static inline void gsCamPushFrame() {}
static inline void gsCamDropClients() {}

#endif  // GS_ENABLE_CAMERA
#endif  // GS_CAMERA_H
