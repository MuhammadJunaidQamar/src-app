# claude code — rewritten ground station firmware

`GS_ALL_PROTOCOLS/` is a rewrite of `esp32/Ground_Station_Code.ino` that speaks
the protocol the Flutter app in `app/src frontend/src` actually implements.

Nothing in the original `esp32/` folder was modified.

```
claude code/
├── README.md                 <- you are here
├── PROTOCOL.md               <- the exact wire contract, field by field
└── GS_ALL_PROTOCOLS/
    ├── GS_ALL_PROTOCOLS.ino  <- setup/loop, ESP-NOW receive, Serial output
    ├── gs_config.h           <- the only file you normally edit
    ├── gs_telemetry.h        <- packet structs + the single JSON encoder
    ├── gs_camera.h           <- ESP-NOW → MJPEG / BLE camera relay
    ├── gs_ble.h              <- NUS GATT server + pairing
    └── gs_net.h              <- SoftAP/STA, HTTP, WebSocket, UDP beacon
```

One firmware carries **every** transport at once, so you flash once and pick the
mode in the app:

| Flutter connection mode | Transport in this firmware |
|---|---|
| Bluetooth ground station | BLE GATT (`CanSat-GS`, Nordic UART + camera service) |
| Wi‑Fi ground station | SoftAP `CanSat-GS` → `ws://192.168.4.1:8765` |
| Router (LAN) ground station | STA + UDP beacon → `ws://<lan-ip>:8765` |
| Broadcast / server | USB Serial → Python relay → app |
| Simulation | no hardware |

---

## Why the base sketch did not work with the app

The base `Ground_Station_Code.ino` runs fine as firmware — it receives ESP‑NOW
and serves HTTP/WebSocket/BLE. The problem is that every payload it produces is
shaped differently from what the app parses. Concretely:

| # | Base sketch | App expects | Symptom |
|---|---|---|---|
| 1 | Nested JSON `{"temperature":…,"acceleration":{"x":…}}` | Flat keys `temp`, `ax`, `gx`, `mx`, `lat`, `lon`, … | Connects, then every gauge reads 0 — this is the "it's only JSON" problem |
| 2 | BLE UUIDs `7d7e1000-…` | Nordic UART `6E400001/2/3-…` | App never finds the characteristics |
| 3 | No writable BLE characteristic | Writes `PAIR:<code>` to RX | BLE pairing can never complete |
| 4 | BLE name `APEXech-GS` | Name contains `CanSat`; reconnect uses exactly `CanSat-GS` | Station is filtered out of the scan list |
| 5 | `/pair` returns a device description, ignores `?code=` | Body must contain `"pair":"ok"` | Wi‑Fi/router pairing always fails |
| 6 | UDP beacon is JSON | Plain text starting with `CANSATGS` | Router mode finds no station |
| 7 | UDP sent only to `255.255.255.255` | — | Many routers drop it; add the `x.x.x.255` subnet address |
| 8 | AP SSID `internet`, no `softAPConfig()` | Join `CanSat-GS`; endpoints hard-coded to `192.168.4.1` | Wrong network, wrong address |
| 9 | Port 81 answers `503 not_configured` | MJPEG `multipart/x-mixed-replace` | Camera tab permanently empty |
| 10 | No CORS headers | Browser preflights the `/pair` GET | Flutter **Web** cannot pair |
| 11 | Only the 76‑byte legacy struct | — | Boards flashed with the 100‑byte struct are rejected |
| 12 | No camera BLE service | 6‑byte header + 244‑byte JPEG slices | No camera over Bluetooth |

Two robustness fixes were folded in as well:

* **`NaN` guard.** A disconnected sensor makes `printf("%f")` emit `nan`, which
  is not valid JSON — `jsonDecode` throws and the app drops the entire packet.
  Non-finite floats are now clamped to `0`.
* **Nothing heavy in the ESP‑NOW callback.** The base sketch did
  `Serial.write()` and an Arduino `String` assignment inside the receive
  callback. That runs on the Wi‑Fi task; `String` allocation there fragments the
  heap and is a classic source of random reboots. The callback now only copies
  bytes and sets flags; all formatting, Serial and BLE work happens in `loop()`.

---

## Flashing

**Libraries** (Arduino IDE → Library Manager):

* `NimBLE-Arduino` (h2zero)
* `WebSockets` (Markus Sattler)

`WiFi`, `WebServer`, `WiFiUdp` and ESP‑NOW ship with the ESP32 core. The sketch
uses the `esp_now_recv_info_t` callback signature, i.e. **ESP32 core 3.x**
(same as the base sketch).

**Board settings**

* Tools → Partition Scheme → **Huge APP (3MB No OTA)** — BLE + Wi‑Fi + camera
  buffers do not fit the default partition.
* Serial Monitor → **115200 baud**.

**Bring-up**

1. Open `GS_ALL_PROTOCOLS/GS_ALL_PROTOCOLS.ino`, edit `gs_config.h` if needed,
   flash, open Serial.
2. Serial prints both MAC addresses. Copy the right one into
   `CANSAT/CANSAT.ino` (`broadcastAddress`) and
   `Camera working code/Tx_camera_code/Tx_camera_code.ino` (`receiverMAC`):
   * SoftAP-only station → **AP MAC**
   * Router (STA) station → **STA MAC**
3. Note the 6-digit **PAIRING CODE** and enter it in the app.

---

## Config presets (`gs_config.h`)

Everything is on by default. Trim only if you are short on flash or RAM.

**Router (LAN) mode** — the one thing you must edit:

```c
#define GS_STA_SSID     "YourRouterSSID"
#define GS_STA_PASSWORD "YourRouterPassword"
```

**Bluetooth-only build** (smallest, most reliable BLE):

```c
#define GS_ENABLE_SOFTAP 0
#define GS_ENABLE_STA    0
```

**Wi‑Fi-only build** (frees ~60 KB, use if BLE and Wi‑Fi fight for RAM):

```c
#define GS_ENABLE_BLE 0
```

**Telemetry-only** (no camera, frees ~40 KB):

```c
#define GS_ENABLE_CAMERA 0
```

**Broadcast / server mode.** `GS_ENABLE_SERIAL_BINARY` is already on and emits
the same 76-byte legacy packet the original firmware did, so the existing
MATLAB / Python readers keep working. If you would rather bridge line-delimited
JSON into the app's WebSocket, switch to:

```c
#define GS_ENABLE_SERIAL_BINARY 0
#define GS_ENABLE_SERIAL_JSON   1
```

Each line is then exactly the payload the app expects — pipe it straight to
`app/websocket/relay.py`.

The human-readable dump and the status block share the same UART as the
telemetry stream, exactly as the original firmware did. Readers normally
resync on the packet header, but for a perfectly clean stream also set:

```c
#define GS_ENABLE_SERIAL_PRETTY 0
#define GS_ENABLE_SERIAL_STATUS 0
```

**Bench testing without a code:**

```c
#define GS_REQUIRE_PAIRING 0
```

---

## Platform notes

| Platform | Works via | Watch out for |
|---|---|---|
| Android | BLE, Wi‑Fi AP, router | Grant Bluetooth **and** location permission; Android may warn that `CanSat-GS` has no internet — stay connected |
| iOS | BLE, Wi‑Fi AP, router | iOS needs "Local Network" permission for LAN/UDP discovery |
| Windows | BLE (WinRT), Wi‑Fi AP, router | If BLE pairing keeps failing, remove `CanSat-GS` from Windows Bluetooth settings and retry with a fresh code — WinRT drops the link during GATT setup |
| macOS / Linux | BLE, Wi‑Fi AP, router | — |
| Web | Wi‑Fi AP, router, BLE (Chromium) | Serve the web build over **http://** or localhost — an https page cannot reach `http://<esp32>` or `ws://<esp32>` (mixed content). UDP discovery does not exist on web, so use "Enter IP manually", or read `/discover`. Web Bluetooth needs a user gesture and Chromium |

---

## Endpoints quick reference

```
http://<station>/            status page
http://<station>/pair?code=NNNNNN
http://<station>/health
http://<station>/telemetry   403 until paired
http://<station>/discover
ws://<station>:8765          telemetry stream
http://<station>:81/stream   MJPEG, 403 until paired
udp  <broadcast>:4210        CANSATGS|<ip>|ws=8765|cam=81|…
```

`<station>` is `192.168.4.1` in Wi‑Fi AP mode, or the LAN IP printed on Serial
in router mode.

---

## Troubleshooting

| Symptom | Check |
|---|---|
| App connects, all values 0 | You flashed the old sketch — the payload must be flat keys (`PROTOCOL.md` §1) |
| `Telemetry: WAITING` forever | CanSat `broadcastAddress` ≠ this board's MAC, or the two are on different Wi‑Fi channels. Serial prints the channel |
| `ESP-NOW: N bad-length` climbing | The CanSat struct does not match; only 76 B, 100 B and 188 B are accepted |
| BLE station missing from the list | Name must contain `CanSat`; check `[BLE] Advertising as "CanSat-GS"` on Serial |
| BLE pairs then drops on Windows | Remove the device from Windows Bluetooth settings, re-read the code, retry |
| Router mode finds nothing | Phone and station must be on the same subnet and AP isolation off; otherwise use manual IP |
| Camera tab empty | Pair first (stream is 403 until paired), and set `receiverMAC` in `Tx_camera_code.ino` to the MAC this board prints |
| Web app cannot pair | Serve the build over http/localhost, not https |
