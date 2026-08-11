# Ground station sketches — which file to flash

| Flutter app mode | Folder / sketch | What it does |
|---|---|---|
| **Bluetooth ground station** | `GROUND_STATION_BLE/GROUND_STATION_BLE.ino` | ESP-NOW in → BLE out to phone |
| **Wi‑Fi ground station** | `GROUND_STATION_WIFI/GROUND_STATION_WIFI.ino` | ESP-NOW in → SoftAP + WebSocket telemetry + MJPEG camera to phone |
| **Router (LAN) ground station** | `GROUND_STATION_ROUTER/GROUND_STATION_ROUTER.ino` | ESP-NOW in → joins your Wi‑Fi router → WebSocket telemetry + MJPEG camera to every device on the router |
| **Broadcast / server** | `GROUND_STATION_BROADCAST/GROUND_STATION_BROADCAST.ino` | ESP-NOW in → USB Serial → Python backend → app |

Open Serial Monitor at **115200 baud**. Each sketch prints a pairing code (Wi‑Fi / BLE) and dumps all sensor fields (temp, accel, gyro, mag, roll/pitch/yaw, GPS).

## Notes

- Flight firmware `CANSAT/CANSAT.ino` still sends the **legacy** packet (no built-in roll/pitch/yaw). Ground stations derive orientation from accel + compass.
- GPS lat/lon stay `0` until the module gets a satellite fix — usual indoors.
- Put the CanSat peer MAC to this board’s STA/AP MAC printed at boot.

## Router (LAN) mode

- Edit `WIFI_SSID` / `WIFI_PASSWORD` at the top of `GROUND_STATION_ROUTER.ino`, then flash.
- Serial prints the **pairing code** — enter only that in the app. The station broadcasts a UDP beacon (`CANSATGS|<ip>` on port 4210) so the phone finds it automatically. Manual IP is an optional fallback. Any number of phones/laptops on the same router can connect; other teams cannot without that station's code.
- No MQTT broker or backend PC is needed — the station serves telemetry itself on `ws://<ip>:8765` (HTTP `/pair`, `/health`, `/telemetry` on port 80).
- **Channel:** ESP-NOW only works when CanSat and GS share a Wi‑Fi channel. The router decides the GS channel. Current `CANSAT.ino` and the camera sender probe channels 1–13 at boot (with retries), then re-probe every few seconds while the link is down — so powering CanSat before the GS still recovers automatically. Set `broadcastAddress` / `receiverMAC` to the GS MAC printed at boot. Serial shows `GS ack=yes/NO`.

## Camera (Wi‑Fi and Router modes)

- Both `GROUND_STATION_WIFI` and `GROUND_STATION_ROUTER` relay ESP32-CAM video: they reassemble the ESP-NOW frame packets and serve MJPEG at `http://<station-ip>:81/stream` (403 until someone has paired). The app opens the stream automatically.
- In `Tx_camera_code.ino`, set `receiverMAC` to the MAC your station prints at boot — the **AP MAC** for the Wi‑Fi station, the **STA MAC** for the router station.
- The camera sender probes channels 1–13 at boot and locks onto the one where the station ACKs, so router channels other than 1 work out of the box. If the station reboots onto a new channel, the sender re-probes after ~5 s of failed deliveries. Serial shows `GS ack=yes/NO` every 3 s.
- Quality is limited by the ESP-NOW radio hop (QQVGA ≈ 5 fps), not by Wi‑Fi/router bandwidth.
