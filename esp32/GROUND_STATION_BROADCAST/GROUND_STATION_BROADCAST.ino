/*
 * CanSat Ground Station — Broadcast / Serial (ESP-NOW → USB Serial)
 *
 * Use this sketch when the Flutter app mode is:
 *   "Broadcast / server"
 *
 * Flow: CanSat --ESP-NOW--> this board --USB Serial--> Python backend
 *       (serial_reader.py / relay) --WebSocket--> Flutter app
 *
 * Prints EVERY sensor field on the Serial Monitor (115200) so you can
 * verify GPS, orientation, IMU, etc. Also emits the legacy binary packet
 * for the Python serial reader.
 *
 * Flash: esp32/GROUND_STATION_BROADCAST/GROUND_STATION_BROADCAST.ino
 */

#include <esp_now.h>
#include <esp_wifi.h>
#include <WiFi.h>
#include <math.h>
#include <string.h>
#include <stdio.h>

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

struct_message myData;
legacy_struct_message legacyOut;
volatile bool telemetryDirty = false;
const char *lastSource = "none";

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
  d.yaw = d.CompassHeading;
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

static void toLegacyOut(const struct_message &d) {
  legacyOut.Header = d.Header ? d.Header : 2864434397UL;
  legacyOut.Temperature = d.Temperature;
  legacyOut.Altitude = d.Altitude;
  legacyOut.Pressure = d.Pressure;
  legacyOut.Heading = d.CompassHeading;
  legacyOut.Xacc = d.Xacc;
  legacyOut.Yacc = d.Yacc;
  legacyOut.Zacc = d.Zacc;
  legacyOut.Angaccx = d.Angaccx;
  legacyOut.Angaccy = d.Angaccy;
  legacyOut.Angaccz = d.Angaccz;
  legacyOut.Magx = d.Magx;
  legacyOut.Magy = d.Magy;
  legacyOut.Magz = d.Magz;
  legacyOut.Sat = d.Sat;
  legacyOut.Lat = d.Lat;
  legacyOut.Long = d.Long;
  legacyOut.GPSAlt = d.GPSAlt;
  legacyOut.TimeStamp = d.timestamp;
}

static void printTelemetrySerial(const struct_message &d, const char *source) {
  Serial.println("---------- TELEMETRY ----------");
  Serial.printf("source=%s  ts=%lu  header=%lu\n", source, d.timestamp, d.Header);
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
    Serial.println("GPS   NOTE: no fix yet (normal indoors — go outside)");
  }
  Serial.println("--------------------------------");
}

void OnDataRecv(const esp_now_recv_info_t *info, const uint8_t *data, int len) {
  (void)info;

  if (len == (int)sizeof(struct_message)) {
    memcpy(&myData, data, sizeof(myData));
    ensureOrientationFromImu(myData);
    lastSource = "new-struct";
    telemetryDirty = true;
    return;
  }

  if (len == (int)sizeof(legacy_struct_message)) {
    legacy_struct_message leg;
    memcpy(&leg, data, sizeof(leg));
    importLegacyTelemetry(leg);
    lastSource = "legacy-CANSAT";
    telemetryDirty = true;
    return;
  }

  static uint32_t lastLenLog = 0;
  if (millis() - lastLenLog >= 5000) {
    lastLenLog = millis();
    Serial.printf("[ESP-NOW] ignored len=%d (new=%u legacy=%u)\n", len,
                  (unsigned)sizeof(struct_message),
                  (unsigned)sizeof(legacy_struct_message));
  }
}

void setup() {
  Serial.begin(115200);
  delay(400);
  Serial.println();
  Serial.println("========================================");
  Serial.println("  CanSat Ground Station (BROADCAST)");
  Serial.println("  ESP-NOW → Serial → Python backend");
  Serial.println("  Flash: GROUND_STATION_BROADCAST.ino");
  Serial.println("  Baud: 115200");
  Serial.println("========================================");

  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  esp_wifi_set_channel(1, WIFI_SECOND_CHAN_NONE);

  uint8_t mac[6];
  WiFi.macAddress(mac);
  Serial.printf("[BOOT] STA MAC (set as CanSat peer): %02X:%02X:%02X:%02X:%02X:%02X\n",
                mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);

  if (esp_now_init() != ESP_OK) {
    Serial.println("ESP-NOW init failed");
  } else {
    esp_now_register_recv_cb(OnDataRecv);
    Serial.println("ESP-NOW ready — waiting for CanSat packets...");
  }

  Serial.printf("[BOOT] packet sizes: new=%u legacy=%u\n",
                (unsigned)sizeof(struct_message),
                (unsigned)sizeof(legacy_struct_message));
}

void loop() {
  if (telemetryDirty) {
    telemetryDirty = false;

    // Human-readable dump for debugging on Serial Monitor.
    static uint32_t lastPrintMs = 0;
    if (millis() - lastPrintMs >= 1000) {
      lastPrintMs = millis();
      printTelemetrySerial(myData, lastSource);
    }

    // Binary legacy packet for Python serial_reader.py
    toLegacyOut(myData);
    Serial.write((uint8_t *)&legacyOut, sizeof(legacyOut));
  }

  static uint32_t lastAlive = 0;
  if (millis() - lastAlive >= 10000) {
    lastAlive = millis();
    Serial.println("[alive] waiting for ESP-NOW telemetry...");
  }

  delay(5);
}
