# WebSocket JSON Format Reference

## Overview

This document describes the JSON format expected from the WebSocket server at `ws://localhost:8765/telemetry`.

## Complete JSON Example

```json
{
  "temp": 21.1,
  "alt": 225.18,
  "press": 98351.0,
  "head": -70.11,
  "ax": 0.396,
  "ay": -0.412,
  "az": -9.829,
  "gx": 0.014,
  "gy": 0.062,
  "gz": 0.0,
  "mx": 2.75,
  "my": -7.6,
  "mz": 2.89,
  "sat": 0.0,
  "lat": 0.0,
  "lon": 0.0,
  "gpsAlt": 0.0,
  "HardwareTimestamp": 3238570,
  "PythonTimestamp": 3241046.53
}
```

## Field Descriptions

### Environmental Sensors

| Field   | Type   | Description          | Unit | Example |
| ------- | ------ | -------------------- | ---- | ------- |
| `temp`  | double | Temperature          | °C   | 21.1    |
| `press` | double | Atmospheric Pressure | Pa   | 98351.0 |
| `alt`   | double | Altitude             | m    | 225.18  |

### Accelerometer (ax, ay, az)

| Field | Type   | Description         | Unit | Example |
| ----- | ------ | ------------------- | ---- | ------- |
| `ax`  | double | Acceleration X-axis | m/s² | 0.396   |
| `ay`  | double | Acceleration Y-axis | m/s² | -0.412  |
| `az`  | double | Acceleration Z-axis | m/s² | -9.829  |

**Note:** Z-axis should be approximately -9.81 m/s² when at rest (gravity).

### Gyroscope (gx, gy, gz)

| Field | Type   | Description             | Unit  | Example |
| ----- | ------ | ----------------------- | ----- | ------- |
| `gx`  | double | Angular velocity X-axis | rad/s | 0.014   |
| `gy`  | double | Angular velocity Y-axis | rad/s | 0.062   |
| `gz`  | double | Angular velocity Z-axis | rad/s | 0.0     |

### Magnetometer (mx, my, mz)

| Field | Type   | Description           | Unit | Example |
| ----- | ------ | --------------------- | ---- | ------- |
| `mx`  | double | Magnetic field X-axis | μT   | 2.75    |
| `my`  | double | Magnetic field Y-axis | μT   | -7.60   |
| `mz`  | double | Magnetic field Z-axis | μT   | 2.89    |

**Note:** Used for compass/heading calculation.

### GPS

| Field    | Type   | Description              | Unit    | Example |
| -------- | ------ | ------------------------ | ------- | ------- |
| `head`   | double | GPS Heading/Bearing      | degrees | -70.11  |
| `sat`    | double | Number of GPS Satellites | count   | 0.0     |
| `lat`    | double | GPS Latitude             | degrees | 0.0     |
| `lon`    | double | GPS Longitude            | degrees | 0.0     |
| `gpsAlt` | double | GPS Altitude             | m       | 0.0     |

**Note:** When GPS is not locked, values may be 0.0 and `sat` will be 0.

### Timestamps

| Field               | Type   | Description             | Unit | Example    |
| ------------------- | ------ | ----------------------- | ---- | ---------- |
| `HardwareTimestamp` | int    | Hardware/MCU timestamp  | ms   | 3238570    |
| `PythonTimestamp`   | double | Python server timestamp | ms   | 3241046.53 |

## Model Mapping

The flat JSON format is automatically mapped to the internal Model structure:

```dart
Model {
  temperature: temp,
  pressure: press,
  altitude: alt,
  acceleration: Acceleration(x: ax, y: ay, z: az),
  rotation: Rotation(x: gx, y: gy, z: gz),
  distance: Distance(x: mx, y: my, z: mz),  // Magnetometer
  gps: GPS(
    heading: head,
    noOfSatellites: sat,
    latitude: lat,
    longitude: lon,
    altitude: gpsAlt
  )
}
```

## Data Types

All numeric fields are parsed flexibly and can be sent as:

- `int` (e.g., `123`)
- `double` (e.g., `123.45`)
- `String` (e.g., `"123.45"`)

The Model class will automatically convert them to the appropriate type.

## Required Fields

**None are strictly required.** All fields are optional. If a field is missing:

- Numeric fields default to `0.0` or `0`
- Objects (GPS, Acceleration, etc.) will be `null` if all their fields are missing

## Example Minimal JSON

```json
{
  "temp": 25.5,
  "press": 101325.0,
  "alt": 100.0
}
```

This is valid and will populate only temperature, pressure, and altitude.

## Testing Your JSON

### Valid Examples

✅ **Full telemetry data:**

```json
{
  "temp": 21.1,
  "press": 98351.0,
  "alt": 225.18,
  "ax": 0.4,
  "ay": -0.4,
  "az": -9.8,
  "gx": 0.01,
  "gy": 0.06,
  "gz": 0.0,
  "mx": 2.75,
  "my": -7.6,
  "mz": 2.89,
  "head": -70.1,
  "sat": 0,
  "lat": 0.0,
  "lon": 0.0,
  "gpsAlt": 0.0
}
```

✅ **Minimal data:**

```json
{ "temp": 20.0, "press": 101325.0 }
```

✅ **Mixed types:**

```json
{ "temp": "21.5", "press": 98351, "alt": 225.18 }
```

### Invalid Examples

❌ **Not JSON:**

```
temp=21.5,press=98351
```

❌ **Invalid JSON syntax:**

```json
{ "temp": 21.5, "press": 98351 } // Missing quotes around keys
```

## Backward Compatibility

The Model class also supports the old nested API format:

```json
{
  "Temperature": 25.5,
  "Pressure": 1013.25,
  "Acceleration": { "X": 0.0, "Y": 0.0, "Z": 9.81 },
  "Rotation": { "X": 0.0, "Y": 0.0, "Z": 0.0 },
  "GPS": {
    "heading": 180.0,
    "noOfSatellites": 8,
    "latitude": 37.7749,
    "longitude": -122.4194,
    "altitude": 50.0
  }
}
```

Both formats work simultaneously, allowing for gradual migration.

## WebSocket Protocol

### Connection

```
ws://localhost:8765/telemetry
```

### Message Flow

```
Client → Server: [Connect]
Server → Client: {"temp": 21.1, "press": 98351.0, ...}
Server → Client: {"temp": 21.2, "press": 98352.0, ...}
Server → Client: {"temp": 21.3, "press": 98353.0, ...}
...
```

### Frequency

- Send data as frequently as needed (e.g., 1Hz, 10Hz, 100Hz)
- No artificial rate limiting on the client side
- Client will process all messages in real-time

### Disconnection

- Client automatically reconnects after 3 seconds if connection is lost
- No action needed from server side

## Common Issues

### Issue: GPS values always 0

**Solution:** This is normal when GPS doesn't have a fix. Wait for satellite lock (`sat` > 0).

### Issue: Acceleration Z-axis not near -9.8

**Solution:** Check sensor calibration or orientation.

### Issue: Data not updating in Flutter app

**Solution:**

1. Verify WebSocket server is sending messages
2. Check console for connection logs
3. Verify JSON format matches this spec

### Issue: Parse errors in Flutter

**Solution:**

1. Validate your JSON using a JSON validator
2. Check field names (case-sensitive)
3. Ensure numeric values are valid numbers

## Testing Tools

### Test with Python

```python
import asyncio
import websockets
import json
import time

async def test_websocket():
    uri = "ws://localhost:8765/telemetry"
    async with websockets.connect(uri) as websocket:
        for i in range(100):
            data = {
                "temp": 20.0 + i * 0.1,
                "press": 98351.0,
                "alt": 225.0 + i,
                "ax": 0.0, "ay": 0.0, "az": -9.81,
                "gx": 0.0, "gy": 0.0, "gz": 0.0,
                "mx": 0.0, "my": 0.0, "mz": 0.0,
                "head": 0.0, "sat": 0, "lat": 0.0, "lon": 0.0, "gpsAlt": 0.0,
                "HardwareTimestamp": int(time.time() * 1000),
                "PythonTimestamp": time.time() * 1000
            }
            await websocket.send(json.dumps(data))
            print(f"Sent: {data['temp']}°C")
            await asyncio.sleep(1)

asyncio.run(test_websocket())
```

### Test with wscat (Node.js)

```bash
npm install -g wscat
wscat -c ws://localhost:8765/telemetry
# Then send: {"temp": 21.1, "press": 98351.0, "alt": 225.18}
```

## Summary

Your WebSocket server should:

1. Accept connections at `ws://localhost:8765/telemetry`
2. Send JSON with lowercase field names (temp, press, alt, etc.)
3. Stream data continuously at any rate
4. All fields are optional
5. The Flutter app will handle the rest!

---

**Need help?** Check `WEBSOCKET_MIGRATION.md` for general WebSocket setup or `WEBSOCKET_OPTIMIZATION_EXAMPLE.md` for performance tips.
