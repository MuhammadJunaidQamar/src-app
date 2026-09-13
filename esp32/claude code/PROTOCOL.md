# Ground station ↔ Flutter wire protocol

Everything in this document is a **contract**. The Flutter app is the reference
implementation; the firmware in `GS_ALL_PROTOCOLS/` matches it exactly. If you
change a key, a UUID or a port here, change it in the app too.

Flutter source of truth:

| Concern | File |
|---|---|
| Telemetry JSON keys | `src frontend/src/lib/model/model.dart` |
| Transports, pairing, BLE UUIDs | `src frontend/src/lib/view_model/view_model.dart` |
| Endpoints per mode | `src frontend/src/lib/utils/connection/connection_config.dart` |
| UDP discovery | `src frontend/src/lib/utils/connection/ground_station_discovery_io.dart` |

---

## 1. Telemetry payload

One JSON object, **flat keys only**. Identical over WebSocket, BLE notify,
HTTP `/telemetry` and (optionally) USB Serial.

```json
{"temp":24.5000,"press":101325.0000,"seaPress":101325.0000,"alt":213.4000,
 "head":142.5000,"ax":0.0120,"ay":-0.0034,"az":9.8100,
 "gx":0.0010,"gy":0.0020,"gz":-0.0005,
 "roll":-0.000347,"pitch":-0.001223,"yaw":142.500000,
 "mx":12.3000,"my":-4.5000,"mz":33.1000,
 "sat":7,"lat":33.684420,"lon":73.047880,"gpsAlt":215.0000,"ts":184213}
```

| Key | Type | Unit | Maps to (`Model`) |
|---|---|---|---|
| `temp` | number | °C | `temperature` |
| `press` | number | Pa | `pressure` |
| `seaPress` | number | Pa | `seaPressure` |
| `alt` | number | m | `altitude` |
| `head` | number | deg 0–360 | `gps.heading` |
| `ax` `ay` `az` | number | m/s² | `acceleration.x/y/z` |
| `gx` `gy` `gz` | number | rad/s | `rotation.x/y/z` |
| `mx` `my` `mz` | number | µT | `distance.x/y/z` (magnetometer) |
| `roll` `pitch` | number | **radians** | `roll`, `pitch` |
| `yaw` | number | deg (compass) | `yaw` — the app converts when `abs(yaw) > 2π` |
| `sat` | number | count | `gps.noOfSatellites` |
| `lat` `lon` | number | deg | `gps.latitude/longitude` |
| `gpsAlt` | number | m | `gps.altitude` |
| `ts` | number | ms since CanSat boot | (not parsed; kept for logging) |

Rules:

* **Flat keys only.** `Model.fromJson` also accepts a legacy nested form
  (`Acceleration: {X,Y,Z}`), but the GPS block there uses different capitalised
  keys and the flat path is the one every current sketch uses. Nested
  `{"acceleration":{"x":…}}` — what the base `Ground_Station_Code.ino` emitted —
  matches **neither** form and parses to an all-`null` model.
* **No `NaN` / `Infinity`.** `printf("%f", NAN)` emits `nan`, which is not
  valid JSON; `jsonDecode` throws and the whole packet is dropped. The firmware
  clamps non-finite floats to `0` before encoding (`gsSanitize`).
* `gps` is only populated by the app when `lat`, `lon` **or** `head` is present,
  so always send all three.
* Rate: capped at 20 Hz (`GS_TELEM_MIN_INTERVAL_MS`). Each ESP-NOW packet is
  sent at most once per transport.

---

## 2. Pairing

One 6-digit code per station, printed on Serial at boot and in every status
block. The same code unlocks every transport.

### Over HTTP (Wi-Fi AP mode and Router mode)

```
GET http://<station>/pair?code=123456
200 {"pair":"ok"}      <- app checks the body contains "pair":"ok"
200 {"pair":"fail"}    <- wrong code (still HTTP 200 on purpose)
400 {"pair":"fail","reason":"missing_code"}
```

The response carries `Access-Control-Allow-Origin: *`, and `OPTIONS` preflights
are answered `204`. Without those two, Flutter **Web** cannot pair at all.

### Over BLE

```
app  -> connect, subscribe to NUS TX
GS   -> {"pair":"required"}
app  -> write "PAIR:123456" to NUS RX   (with or without response)
GS   -> {"pair":"ok"}   or   {"pair":"fail"}
```

The app treats any frame shorter than 32 bytes that starts with `{"pair":` as a
control frame, not telemetry, so pair replies never reach the JSON decoder.

### Over WebSocket (extra, not used by the app)

Send the text frame `PAIR:123456`; the station replies `{"pair":"ok"}` or
`{"pair":"fail"}`. Useful when a browser blocks the cross-origin HTTP GET but
the WebSocket handshake succeeds.

Until a client pairs: HTTP `/telemetry` returns `403`, the MJPEG port returns
`403`, and the WebSocket sends the plain-text frame `pair_required` on connect
instead of telemetry.

That greeting is deliberately **not** JSON. The app pushes every WebSocket
frame straight into `Model.fromJson`, and any JSON object it does not
recognise becomes an all-`null` `Model` that propagates to the dashboard.
Plain text makes `jsonDecode` throw, which the app already catches and ignores.

---

## 3. BLE GATT

Advertised name **`CanSat-GS`** — the app filters scan results on
`platformName.contains('CanSat')` and reconnects with
`withNames: ['CanSat-GS']`, so the name is part of the protocol.

| Role | UUID | Properties |
|---|---|---|
| NUS service | `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` | — |
| TX (station → app) | `6E400003-B5A3-F393-E0A9-E50E24DCCA9E` | NOTIFY, READ |
| RX (app → station) | `6E400002-B5A3-F393-E0A9-E50E24DCCA9E` | WRITE, WRITE_NR |
| Camera service | `6E400010-B5A3-F393-E0A9-E50E24DCCA9E` | — |
| Camera TX | `6E400011-B5A3-F393-E0A9-E50E24DCCA9E` | NOTIFY, READ |

Both service UUIDs must be in the advertisement: on Web the app calls
`startScan(withServices: [nus, cam])`, and Web Bluetooth refuses access to any
service that was not requested. A 128-bit UUID plus a name does not fit in the
31-byte advertising packet, so scan response is enabled and the name goes there.

MTU is set to 517 so a ~400-byte telemetry object fits in one notify.

### Camera frame chunking

Each notify is a 6-byte **big-endian** header followed by ≤ 244 JPEG bytes:

```
byte 0-1  frameId
byte 2-3  packetId      (0-based)
byte 4-5  totalPackets
byte 6..  JPEG slice
```

The app buffers by `packetId`, restarts on `packetId == 0` or a new `frameId`,
and only emits a frame once every slice is present and the result starts with
`FF D8` and ends with `FF D9`.

---

## 4. Network endpoints

| Port | Protocol | Path | Notes |
|---|---|---|---|
| 80 | HTTP | `/pair?code=` | pairing, CORS enabled |
| 80 | HTTP | `/health` | status JSON |
| 80 | HTTP | `/telemetry` | latest packet, 403 until paired |
| 80 | HTTP | `/discover` | endpoint card (useful on Web, which has no UDP) |
| 8765 | WebSocket | `/` | telemetry stream; `ping` → `pong` |
| 81 | HTTP | `/stream` (any path) | `multipart/x-mixed-replace; boundary=frame` |
| 4210 | UDP | — | discovery beacon, broadcast every 2 s |

Wi-Fi AP mode addresses are fixed by the app: `ws://192.168.4.1:8765` and
`http://192.168.4.1:81/stream`. The firmware pins the SoftAP to 192.168.4.1.

---

## 5. UDP discovery beacon

**Plain text, not JSON.** `discoverGroundStationHosts` rejects anything that
does not start with `CANSATGS`:

```
CANSATGS|192.168.1.50|ws=8765|cam=81|http=80|paired=0|telem=1
```

The app splits on `|` and uses field 1 as the host (falling back to the sender
address). The trailing `key=value` fields are ignored by the app and available
to other tooling.

Sent every 2 s to the subnet broadcast address (`x.x.x.255`) **and** to
`255.255.255.255`. The subnet address matters — plenty of routers drop the
global broadcast, which is why router mode never found the station before.

---

## 6. ESP-NOW uplink (CanSat / camera → ground station)

Packets are identified by length, so both flight-firmware generations work
against the same ground station:

| Length | Meaning |
|---|---|
| 76 B | legacy `struct_message` — `CANSAT/CANSAT.ino` |
| 100 B | extended struct with `roll/pitch/yaw`, `Distance`, `TotalDistance` |
| 188 B | `GsCamPacket` — `Camera working code/Tx_camera_code` |
| other | counted in `packet_errors`, ignored |

The legacy packet has no orientation, so the station derives it:

```
roll  = atan2(ay, az)                      // radians
pitch = atan2(-ax, sqrt(ay² + az²))        // radians
yaw   = compass heading                    // degrees
```

ESP-NOW rides the active Wi-Fi channel. In SoftAP-only mode the channel is
`GS_AP_CHANNEL`; once the station joins a router, the router owns the channel.
`CANSAT.ino` and `Tx_camera_code.ino` probe channels 1–13 and re-lock, so this
recovers by itself.
