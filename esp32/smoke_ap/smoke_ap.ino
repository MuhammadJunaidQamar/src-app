/*
  Minimal Soft AP — no ESP-NOW, no WebServer.
  Open Arduino IDE → open this folder as a sketch → Board: ESP32 Dev Module → Upload.
  Phone should see SSID "ESP-SMOKE" on 2.4 GHz. If not, suspect USB power, antenna, or bad module.
*/
#include <esp_wifi.h>
#include <WiFi.h>

void setup() {
  Serial.begin(115200);
  delay(800);
  Serial.println();
  Serial.println("smoke_ap: starting OPEN AP ESP-SMOKE on channel 6 ...");

  WiFi.persistent(false);
  WiFi.mode(WIFI_AP);
  esp_wifi_set_ps(WIFI_PS_NONE);

  const char *ssid = "ESP-SMOKE";
  bool ok = WiFi.softAP(ssid, nullptr, 6, 0, 4);
  Serial.println(ok ? "softAP OK" : "softAP FAILED");

  Serial.print("IP: ");
  Serial.println(WiFi.softAPIP());
  Serial.print("Mode: ");
  Serial.println((int)WiFi.getMode());
  Serial.println("Look for SSID: ESP-SMOKE (open network)");
}

void loop() {
  delay(5000);
  Serial.print("stations: ");
  Serial.println(WiFi.softAPgetStationNum());
}
