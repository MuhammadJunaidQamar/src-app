#include "esp_camera.h"
#include <WiFi.h>
#include <esp_now.h>
#include <esp_wifi.h>

// !! MUST match BLE ground station boot line:
//   [BOOT] MAC (use in Tx_camera receiverMAC): XX:XX:XX:XX:XX:XX
uint8_t receiverMAC[] = {0x28, 0x56, 0x2F, 0x77, 0x76, 0x30};

typedef struct __attribute__((packed))
{
  uint16_t frame_id;
  uint16_t packet_id;
  uint16_t total_packets;
  uint16_t size;
  uint8_t data[180];
} Packet;

#define CAM_PACKET_LEN 188

Packet packet;

esp_now_peer_info_t peerInfo;
uint16_t frame_id = 0;

// ================= CAMERA PINS (AI THINKER) =================
#define PWDN_GPIO_NUM 32
#define RESET_GPIO_NUM -1
#define XCLK_GPIO_NUM 0
#define SIOD_GPIO_NUM 26
#define SIOC_GPIO_NUM 27

#define Y9_GPIO_NUM 35
#define Y8_GPIO_NUM 34
#define Y7_GPIO_NUM 39
#define Y6_GPIO_NUM 36
#define Y5_GPIO_NUM 21
#define Y4_GPIO_NUM 19
#define Y3_GPIO_NUM 18
#define Y2_GPIO_NUM 5
#define VSYNC_GPIO_NUM 25
#define HREF_GPIO_NUM 23
#define PCLK_GPIO_NUM 22

// ================= INIT CAMERA =================
void initCamera()
{
  camera_config_t config;

  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;

  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;

  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;

  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;

  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;

  config.xclk_freq_hz = 20000000;

  config.pixel_format = PIXFORMAT_JPEG;
  config.frame_size = FRAMESIZE_QQVGA; // 160×120 — smaller JPEG for BLE relay
  config.jpeg_quality = 15;
  config.fb_count = 2; // double-buffer for smoother capture

  esp_camera_init(&config);
}

// ================= INIT ESP-NOW =================
void initEspNow()
{
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  esp_wifi_set_channel(1, WIFI_SECOND_CHAN_NONE);

  if (esp_now_init() != ESP_OK)
  {
    Serial.println("ESP-NOW init failed");
    return;
  }

  memcpy(peerInfo.peer_addr, receiverMAC, 6);
  peerInfo.channel = 1;
  peerInfo.encrypt = false;

  if (esp_now_add_peer(&peerInfo) != ESP_OK)
  {
    Serial.println("ESP-NOW add_peer failed — check receiverMAC");
  }
}

// ================= SEND FRAME =================
void sendFrame(camera_fb_t *fb)
{
  if (!fb || fb->len == 0)
    return;

  uint16_t total = (uint16_t)((fb->len + 179) / 180);
  if (total == 0)
    total = 1;

  for (uint16_t i = 0; i < total; i++)
  {

    packet.frame_id = frame_id;
    packet.packet_id = i;
    packet.total_packets = total;

    packet.size = 180;

    if (i == total - 1)
      packet.size = fb->len - (i * 180);

    memcpy(packet.data,
           fb->buf + (i * 180),
           packet.size);

    const esp_err_t err =
        esp_now_send(receiverMAC, (uint8_t *)&packet, CAM_PACKET_LEN);
    if (err != ESP_OK && i == 0) {
      static uint32_t lastErr = 0;
      if (millis() - lastErr >= 3000) {
        lastErr = millis();
        Serial.printf("[CAM-TX] esp_now_send failed: %d\n", (int)err);
      }
    }

    delay(2);
  }

  frame_id++;

  static uint32_t lastLog = 0;
  if (millis() - lastLog >= 3000)
  {
    lastLog = millis();
    Serial.printf("[CAM-TX] frame %u | jpeg %u B | %u packets\n",
                  frame_id - 1, fb->len, total);
  }
}

// ================= SETUP =================
void setup()
{
  Serial.begin(115200);
  delay(500);

  initCamera();
  initEspNow();

  Serial.printf("CAM SENDER READY | packet=%u bytes | peer MAC %02X:%02X:%02X:%02X:%02X:%02X\n",
                (unsigned)CAM_PACKET_LEN,
                receiverMAC[0], receiverMAC[1], receiverMAC[2],
                receiverMAC[3], receiverMAC[4], receiverMAC[5]);
}

// ================= LOOP =================
void loop()
{

  camera_fb_t *fb = esp_camera_fb_get();

  if (!fb)
    return;

  sendFrame(fb);

  esp_camera_fb_return(fb);

  delay(200); // ≈ 5 FPS target. Reduce to 100 for 10 FPS (needs QQVGA), increase if frames corrupt
}