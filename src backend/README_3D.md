# CanSat Ground Station - Enhanced 3D Version

## Overview

You now have **TWO versions** of the Python backend:

### 1. **Simple Version** (Original) - `main.py`
- ✅ Stable and lightweight
- ✅ Two separate windows (CanSat + Gyro)
- ✅ Simple 2D circular dials
- ✅ Text-based sensor display
- ✅ WebSocket support
- ✅ Already updated for your ESP32 structure

### 2. **Enhanced 3D Version** (NEW!) - `main_3d.py` ⭐
- ✅ **3D rotating cylinder visualization**
- ✅ Beautiful tabbed interface
- ✅ Real-time graphs for ALL sensors
- ✅ Modern dark theme (#070814)
- ✅ Circular needle dials
- ✅ WebSocket support
- ✅ Updated for your ESP32 structure
- ✅ Displays roll, pitch, yaw, distance, totalDistance

---

## Installation

### Install Additional Dependencies (for 3D version)

```bash
cd "src backend"
pip install numpy matplotlib
```

### Existing Dependencies (already have these)
```bash
pip install pyserial websockets pillow
```

---

## How to Run

### **Option A: Simple Version** (Recommended for testing)

```bash
cd "src backend"

# Optional: Enable WebSocket
$env:CANSAT_WS_URL="ws://localhost:8765/telemetry"  # Windows PowerShell

python main.py
```

**Opens:** 2 separate windows
- Main window with sensor data
- Gyro window with 2D dials

---

### **Option B: Enhanced 3D Version** (Full Features!) ⭐

```bash
cd "src backend"

# Optional: Enable WebSocket
$env:CANSAT_WS_URL="ws://localhost:8765/telemetry"  # Windows PowerShell

python main_3d.py
```

**Opens:** 1 tabbed window
- **Tab 1: Environment & Sensors**
  - Real-time scrolling graphs for ALL 18 sensors
  - Temperature, Pressure, Altitude
  - Accelerometer (X, Y, Z)
  - **Roll, Pitch, Yaw** (from ESP32)
  - Magnetometer (X, Y, Z)
  - Compass heading
  - GPS data (Satellites, Lat, Lon)
  - **Distance tracking** (current, total)

- **Tab 2: Gyro (3D Visualization)**
  - **3D rotating cylinder** showing orientation
  - X/Y/Z coordinate axes (Red/Green/Blue)
  - Gyro rates display (rad/s)
  - Integrated angles display (degrees)
  - 3 circular needle dials
  - Reset button

---

## Complete System Startup

### **Step 1: Start WebSocket Relay** (Terminal 1)
```bash
cd websocket
python relay.py
```
Wait for: `Relay ready (path=/telemetry)`

### **Step 2: Start Python Backend** (Terminal 2)

**For Simple Version:**
```bash
cd "src backend"
$env:CANSAT_WS_URL="ws://localhost:8765/telemetry"
python main.py
```

**For 3D Version:**
```bash
cd "src backend"
$env:CANSAT_WS_URL="ws://localhost:8765/telemetry"
python main_3d.py
```

- Select COM port when prompted
- Wait for data to flow

### **Step 3: Start Flutter Frontend** (Terminal 3)
```bash
cd "src frontend/src"
flutter run -d windows
```

---

## Features Comparison

| Feature | `main.py` (Simple) | `main_3d.py` (Enhanced) |
|---------|-------------------|------------------------|
| **3D Visualization** | ❌ No | ✅ **YES - Rotating Cylinder!** |
| **2D Circular Dials** | ✅ Yes | ✅ Yes |
| **Real-time Graphs** | ❌ No | ✅ Yes - All 18 sensors |
| **Tabbed Interface** | ❌ 2 windows | ✅ 1 window, 2 tabs |
| **Dark Theme** | ⚪ Black/Gold | ✅ Modern (#070814) |
| **Roll/Pitch/Yaw Display** | ❌ No | ✅ Yes |
| **Distance Tracking** | ❌ No | ✅ Yes |
| **WebSocket Streaming** | ✅ Yes | ✅ Yes |
| **CSV Logging** | ✅ Yes | ✅ Yes |
| **Gyro Bias Calibration** | ✅ Yes (300 samples) | ✅ Yes (50 samples) |
| **ESP32 Packet Support** | ✅ Updated | ✅ Updated |
| **Memory Usage** | 🟢 Low | 🟡 Medium |
| **CPU Usage** | 🟢 Low | 🟡 Medium |
| **Startup Time** | 🟢 Fast | 🟡 Slower |

---

## Data Displayed

### **All Versions Support:**
- Accelerometer (ax, ay, az)
- Gyroscope (gx, gy, gz)
- Magnetometer (mx, my, mz)
- Temperature, Pressure, Altitude
- Compass Heading
- GPS (Satellites, Lat, Lon, Alt)

### **Only in 3D Version:**
- **Roll, Pitch, Yaw** (NEW from ESP32) with graphs
- **Distance tracking** (current, total) with graphs
- **3D rotating visualization**
- **Real-time scrolling graphs** for all sensors

---

## Controls

### **3D Version Controls:**
- **Reset Orientation Button** - Resets integrated angles to zero
- **Mouse Wheel** - Scroll through sensor graphs
- **Tab Switch** - Switch between Environment and Gyro tabs

### **Simple Version Controls:**
- **Reset Angles Button** - Resets gyro angles (in Gyro window)

---

## Troubleshooting

### 3D Version is Slow
- The 3D cylinder updates are throttled to 50ms (20 FPS)
- Close other applications
- Use Simple version if needed

### Missing Dependencies
```bash
pip install numpy matplotlib websockets pyserial pillow
```

### ImportError: No module named 'tkintermapview'
The 3D version doesn't use TkinterMapView (GPS map removed for stability). If you see this error, it means you're running old code.

### Gyro Calibration Takes Time
- Simple version: Calibrates for 300 samples (~30 seconds)
- 3D version: Calibrates for 50 samples (~5 seconds)
- Keep device stationary during calibration

### Console Output is Messy
Press `Ctrl+C` to stop, then restart. The live updating output should display cleanly.

---

## File Structure

```
src backend/
├── main.py              # Simple version (original)
├── main_3d.py           # Enhanced 3D version (NEW!)
├── main_gui_3d.py       # 3D GUI components (NEW!)
├── sensor_gui.py        # Simple sensor GUI
├── gyro_gui.py          # Simple gyro GUI
├── serial_reader.py     # Serial packet parser (updated for ESP32)
├── serial_port_button.py # COM port selector
├── README_3D.md         # This file
└── requirements_3d.txt  # Dependencies for 3D version
```

---

## CSV Logging

Both versions log to:
```
cansat_log_YYYYMMDD_HHMMSS.csv
```

**Columns:** HardwareTimestamp, PythonTimestamp, ax, ay, az, gx, gy, gz, mx, my, mz, temp, press, alt, head, sat, lat, lon, gpsAlt

---

## WebSocket Streaming

Both versions support WebSocket streaming (optional).

**Enable:**
```bash
# Windows PowerShell
$env:CANSAT_WS_URL="ws://localhost:8765/telemetry"

# Windows CMD
set CANSAT_WS_URL=ws://localhost:8765/telemetry

# Linux/Mac
export CANSAT_WS_URL="ws://localhost:8765/telemetry"
```

**Disable:**
Don't set the environment variable or set it to empty string.

---

## Performance Tips

### For 3D Version:
1. Close unnecessary browser tabs
2. Reduce graph buffer length (edit `self.buf_len = 200` in main_gui_3d.py)
3. Increase throttle delay (edit `GYRO_DRAW_MIN_MS = 50` to `100` or higher)
4. Use Simple version if performance is critical

### For Both Versions:
1. Use baud rate 115200 (default)
2. Flush CSV every 100 packets (default)
3. Close unused applications

---

## Known Limitations

### 3D Version:
- Requires more CPU/RAM
- Slightly slower startup
- No GPS map (removed for stability)

### Simple Version:
- No 3D visualization
- No real-time graphs
- Separate windows (can be cluttered)

---

## Recommendation

**For normal use:** `main_3d.py` - You get the full experience with 3D visualization!

**For low-power systems or debugging:** `main.py` - Fast and reliable

**For demonstrations:** `main_3d.py` - Looks impressive! 🚀

---

## Need Help?

Check the console output for error messages. Common issues:
- Serial port not found → Check ESP32 connection
- WebSocket errors → Check relay.py is running
- Import errors → Install missing dependencies
- Slow performance → Try Simple version

---

**Enjoy your enhanced CanSat Ground Station!** 🛰️✨



