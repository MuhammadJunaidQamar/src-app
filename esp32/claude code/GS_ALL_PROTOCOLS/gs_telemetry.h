/*
  gs_telemetry.h — telemetry structs, shared state, and the ONE JSON encoder
  every transport uses.

  Why this file exists
  --------------------
  The original Ground_Station_Code.ino emitted nested JSON
  ({"temperature":..,"acceleration":{"x":..}}). The Flutter app's
  Model.fromJson (lib/model/model.dart) only understands FLAT short keys
  (temp, ax, gx, mx, lat, lon, ...), so that payload parsed into an empty
  model and every gauge stayed at zero. The encoder below emits exactly the
  keys Model.fromJson looks for — see PROTOCOL.md.
*/

#ifndef GS_TELEMETRY_H
#define GS_TELEMETRY_H

#include <Arduino.h>
#include <math.h>
#include <esp_random.h>
#include <stdio.h>
#include <string.h>

#include "gs_config.h"

// ============================================================
// PACKET LAYOUTS
// ============================================================
// Two flight-firmware layouts exist in this project and both are accepted;
// they are told apart by the esp_now_recv length, so a CanSat can be
// re-flashed without touching the ground station.

// Legacy layout (76 B) — CANSAT/CANSAT.ino and the original
// Ground_Station_Code.ino. KEEP IDENTICAL TO THE TRANSMITTER.
typedef struct legacy_struct_message {
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
} legacy_struct_message;

// Extended layout (100 B) — carries roll/pitch/yaw computed on the CanSat.
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

// ============================================================
// SHARED STATE
// ============================================================
// gsTelem is written from the ESP-NOW callback and read from loop(). The
// callback runs on the Wi-Fi task, so the swap is guarded by a spinlock and
// the callback itself does no allocation, no Serial and no BLE work.

portMUX_TYPE gsTelemMux = portMUX_INITIALIZER_UNLOCKED;

struct_message gsTelem;                    // canonical copy, always extended
volatile bool     gsHasTelemetry   = false;
volatile bool     gsTelemetryDirty = false;
volatile uint32_t gsPacketCount    = 0;
volatile uint32_t gsErrorCount     = 0;
volatile uint32_t gsLastTelemMs    = 0;

uint8_t       gsLastSrcMac[6]  = {0};
volatile bool gsSrcMacValid    = false;
volatile bool gsLastWasLegacy  = true;

// Pairing is shared by every transport: one code unlocks BLE, WebSocket,
// HTTP /telemetry and the MJPEG stream.
char gsPairCode[7] = "000000";
volatile bool gsPaired = false;

// ============================================================
// HELPERS
// ============================================================

static void gsMacToStr(const uint8_t *mac, char *out, size_t outLen) {
  snprintf(out, outLen, "%02X:%02X:%02X:%02X:%02X:%02X",
           mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
}

// A NaN or Inf from a disconnected sensor prints as "nan"/"inf", which is not
// valid JSON — jsonDecode throws and the app silently drops the whole packet.
// Clamp non-finite floats before they reach the encoder.
static inline float gsFinite(float v) {
  return isfinite(v) ? v : 0.0f;
}

static void gsSanitize(struct_message &d) {
  d.Xacc = gsFinite(d.Xacc);
  d.Yacc = gsFinite(d.Yacc);
  d.Zacc = gsFinite(d.Zacc);
  d.Angaccx = gsFinite(d.Angaccx);
  d.Angaccy = gsFinite(d.Angaccy);
  d.Angaccz = gsFinite(d.Angaccz);
  d.roll = gsFinite(d.roll);
  d.pitch = gsFinite(d.pitch);
  d.yaw = gsFinite(d.yaw);
  d.Magx = gsFinite(d.Magx);
  d.Magy = gsFinite(d.Magy);
  d.Magz = gsFinite(d.Magz);
  d.Temperature = gsFinite(d.Temperature);
  d.Altitude = gsFinite(d.Altitude);
  d.Pressure = gsFinite(d.Pressure);
  d.CompassHeading = gsFinite(d.CompassHeading);
  d.GPSHeading = gsFinite(d.GPSHeading);
  d.Sat = gsFinite(d.Sat);
  d.Lat = gsFinite(d.Lat);
  d.Long = gsFinite(d.Long);
  d.GPSAlt = gsFinite(d.GPSAlt);
  d.Distance = gsFinite(d.Distance);
  d.TotalDistance = gsFinite(d.TotalDistance);
}

// The legacy packet carries no orientation, so derive it here. Otherwise the
// app's 3-D plane and compass sit at zero forever.
static void gsEnsureOrientation(struct_message &d) {
  const bool unset =
      (fabsf(d.roll) < 1e-6f && fabsf(d.pitch) < 1e-6f && fabsf(d.yaw) < 1e-6f);
  if (!unset) return;

  const float ax = d.Xacc, ay = d.Yacc, az = d.Zacc;
  const float denom = sqrtf(ay * ay + az * az);
  if (denom > 1e-4f) {
    d.roll  = atan2f(ay, az);      // radians
    d.pitch = atan2f(-ax, denom);  // radians
  }
  // Compass heading is degrees (0-360); the app converts when |yaw| > 2 pi.
  d.yaw = d.CompassHeading;
}

static void gsImportLegacy(const legacy_struct_message &leg, struct_message &d) {
  d.Header         = leg.Header;
  d.timestamp      = leg.TimeStamp;
  d.Temperature    = leg.Temperature;
  d.Altitude       = leg.Altitude;
  d.Pressure       = leg.Pressure;
  d.CompassHeading = leg.Heading;
  d.GPSHeading     = leg.Heading;
  d.Xacc = leg.Xacc;
  d.Yacc = leg.Yacc;
  d.Zacc = leg.Zacc;
  d.Angaccx = leg.Angaccx;
  d.Angaccy = leg.Angaccy;
  d.Angaccz = leg.Angaccz;
  d.Magx = leg.Magx;
  d.Magy = leg.Magy;
  d.Magz = leg.Magz;
  d.Sat = leg.Sat;
  d.Lat = leg.Lat;
  d.Long = leg.Long;
  d.GPSAlt = leg.GPSAlt;
  d.roll = 0.0f;
  d.pitch = 0.0f;
  d.yaw = 0.0f;
  d.Distance = 0.0f;
  d.TotalDistance = 0.0f;
}

static void gsExportLegacy(const struct_message &d, legacy_struct_message &leg) {
  leg.Header      = d.Header;
  leg.Temperature = d.Temperature;
  leg.Altitude    = d.Altitude;
  leg.Pressure    = d.Pressure;
  leg.Heading     = d.CompassHeading;
  leg.Xacc = d.Xacc;
  leg.Yacc = d.Yacc;
  leg.Zacc = d.Zacc;
  leg.Angaccx = d.Angaccx;
  leg.Angaccy = d.Angaccy;
  leg.Angaccz = d.Angaccz;
  leg.Magx = d.Magx;
  leg.Magy = d.Magy;
  leg.Magz = d.Magz;
  leg.Sat = d.Sat;
  leg.Lat = d.Lat;
  leg.Long = d.Long;
  leg.GPSAlt = d.GPSAlt;
  leg.TimeStamp = d.timestamp;
}

/// Snapshot the shared telemetry so formatting happens outside the lock.
static bool gsCopyTelemetry(struct_message &out) {
  bool available;
  portENTER_CRITICAL(&gsTelemMux);
  out = gsTelem;
  available = gsHasTelemetry;
  portEXIT_CRITICAL(&gsTelemMux);
  return available;
}

// ============================================================
// JSON ENCODER  (PROTOCOL — keys must match Model.fromJson)
// ============================================================
// Built with snprintf into a caller-owned buffer, never an Arduino String:
// this runs at 20 Hz next to NimBLE and the Wi-Fi stack, and String churn
// there is what fragments the heap.
//
// Returns the length written, or 0 if it did not fit.

static size_t gsBuildTelemetryJson(const struct_message &in, char *out, size_t outLen) {
  struct_message d = in;
  gsSanitize(d);

  const int n = snprintf(
      out, outLen,
      "{"
      "\"temp\":%.4f,"
      "\"press\":%.4f,"
      "\"seaPress\":%.4f,"
      "\"alt\":%.4f,"
      "\"head\":%.4f,"
      "\"ax\":%.4f,\"ay\":%.4f,\"az\":%.4f,"
      "\"gx\":%.4f,\"gy\":%.4f,\"gz\":%.4f,"
      "\"roll\":%.6f,\"pitch\":%.6f,\"yaw\":%.6f,"
      "\"mx\":%.4f,\"my\":%.4f,\"mz\":%.4f,"
      "\"sat\":%.0f,\"lat\":%.6f,\"lon\":%.6f,\"gpsAlt\":%.4f,"
      "\"ts\":%lu"
      "}",
      d.Temperature,
      d.Pressure,
      d.Pressure,            // seaPress: no sea-level reference on the GS
      d.Altitude,
      d.CompassHeading,
      d.Xacc, d.Yacc, d.Zacc,
      d.Angaccx, d.Angaccy, d.Angaccz,
      d.roll, d.pitch, d.yaw,
      d.Magx, d.Magy, d.Magz,
      d.Sat, d.Lat, d.Long, d.GPSAlt,
      (unsigned long)d.timestamp);

  if (n < 0 || (size_t)n >= outLen) return 0;
  return (size_t)n;
}

static void gsPrintTelemetry(const struct_message &d, const char *source) {
  Serial.println("---------- TELEMETRY ----------");
  Serial.printf("source=%s  ts=%lu  header=%lu\n",
                source, (unsigned long)d.timestamp, (unsigned long)d.Header);
  Serial.printf("ENV   temp=%.2f C  alt=%.2f m  press=%.1f Pa\n",
                d.Temperature, d.Altitude, d.Pressure);
  Serial.printf("ACC   ax=%.3f  ay=%.3f  az=%.3f\n", d.Xacc, d.Yacc, d.Zacc);
  Serial.printf("GYRO  gx=%.3f  gy=%.3f  gz=%.3f\n",
                d.Angaccx, d.Angaccy, d.Angaccz);
  Serial.printf("MAG   mx=%.3f  my=%.3f  mz=%.3f  compass=%.1f deg\n",
                d.Magx, d.Magy, d.Magz, d.CompassHeading);
  Serial.printf("ORI   roll=%.4f rad  pitch=%.4f rad  yaw=%.2f\n",
                d.roll, d.pitch, d.yaw);
  Serial.printf("GPS   sat=%.0f  lat=%.6f  lon=%.6f  gpsAlt=%.2f\n",
                d.Sat, d.Lat, d.Long, d.GPSAlt);
  if (d.Sat < 1.0f || (fabsf(d.Lat) < 1e-6f && fabsf(d.Long) < 1e-6f)) {
    Serial.println("GPS   NOTE: no fix yet (normal indoors)");
  }
  Serial.println("--------------------------------");
}

// ============================================================
// PAIRING CODE
// ============================================================

static void gsGeneratePairCode() {
  if (sizeof(GS_FIXED_PAIR_CODE) - 1 == 6) {
    strncpy(gsPairCode, GS_FIXED_PAIR_CODE, sizeof(gsPairCode) - 1);
    gsPairCode[6] = 0;
  } else {
    const uint32_t n = esp_random() % 1000000UL;
    snprintf(gsPairCode, sizeof(gsPairCode), "%06lu", (unsigned long)n);
  }
  gsPaired = false;
  Serial.printf("\n*** PAIRING CODE: %s ***\n\n", gsPairCode);
}

/// Check a 6-digit code supplied by a client over BLE or HTTP.
static bool gsCheckPairCode(const char *candidate, size_t len) {
#if !GS_REQUIRE_PAIRING
  (void)candidate;
  (void)len;
  return true;
#else
  if (len != 6) return false;
  return strncmp(candidate, gsPairCode, 6) == 0;
#endif
}

#endif  // GS_TELEMETRY_H
