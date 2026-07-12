#include <WiFi.h>
#include <esp_now.h>
#include <TFT_eSPI.h>
#include <TJpg_Decoder.h>

TFT_eSPI tft = TFT_eSPI();

#define MAX_JPEG_SIZE 30000

uint8_t jpgBuffer[MAX_JPEG_SIZE];
uint32_t writeIndex = 0;

volatile bool frameReady = false;
volatile bool drawing = false;

typedef struct {
  uint16_t frame_id;
  uint16_t packet_id;
  uint16_t total_packets;
  uint16_t size;
  uint8_t data[180];
} Packet;

Packet packet;

// ================= RESET =================
void resetFrame() {
  writeIndex = 0;
}

// ================= ESP-NOW RECEIVE =================
void OnDataRecv(const esp_now_recv_info_t *info,
                const uint8_t *incomingData,
                int len) {

  if (drawing) return;

  memcpy(&packet, incomingData, sizeof(packet));

  if (packet.packet_id == 0) {
    resetFrame();
  }

  if (writeIndex + packet.size < MAX_JPEG_SIZE) {
    memcpy(jpgBuffer + writeIndex,
           packet.data,
           packet.size);

    writeIndex += packet.size;
  }

  if (packet.packet_id == packet.total_packets - 1) {
    frameReady = true;
  }
}

// ================= TFT JPEG CALLBACK =================
bool tft_output(int16_t x, int16_t y,
                uint16_t w, uint16_t h,
                uint16_t *bitmap) {

  tft.pushImage(x, y, w, h, bitmap);
  return 1;
}

// ================= SETUP =================
void setup() {
  Serial.begin(115200);

  WiFi.mode(WIFI_STA);
  WiFi.setSleep(true);

  esp_now_init();
  esp_now_register_recv_cb(OnDataRecv);

  tft.init();
  tft.setRotation(1);

  // 🔥 IMPORTANT RGB FIX
  tft.setSwapBytes(true);

  tft.fillScreen(TFT_BLACK);

  TJpgDec.setCallback(tft_output);
  TJpgDec.setJpgScale(1);

  Serial.println("TFT RECEIVER READY");
}

// ================= LOOP =================
void loop() {

  if (frameReady) {

    frameReady = false;
    drawing = true;

    Serial.print("FRAME SIZE: ");
    Serial.println(writeIndex);

    if (jpgBuffer[0] == 0xFF && jpgBuffer[1] == 0xD8) {

      tft.fillScreen(TFT_BLACK);

      TJpgDec.drawJpg(0, 0, jpgBuffer, writeIndex);

      Serial.println("FRAME DISPLAY OK");
    } else {
      Serial.println("CORRUPTED FRAME");
    }

    drawing = false;

    delay(2000); // 🔥 LOW FPS STABILITY
  }
}