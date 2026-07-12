# 🚀 Complete System Startup Order

## Overview
Your CanSat system has **3 parts** that work together:
1. ✅ WebSocket Relay (forwards data)
2. ✅ Python Backend (receives from ESP32, 2 versions to choose from)
3. ✅ Flutter Frontend (displays on mobile/desktop)

---

## Startup Sequence

### 🔷 Step 1: WebSocket Relay (FIRST)

**Terminal/Command Prompt 1:**
```bash
cd websocket
python relay.py
```

**Wait for this message:**
```
[INFO] cansat.websocket.relay: Relay ready (path=/telemetry)
```

✅ **Keep this running!** Don't close this terminal.

---

### 🔷 Step 2: Python Backend (SECOND)

**Terminal/Command Prompt 2:**

#### Option A: Simple Version
```bash
cd "src backend"

# Enable WebSocket (Optional)
$env:CANSAT_WS_URL="ws://localhost:8765/telemetry"  # Windows PowerShell
# OR
set CANSAT_WS_URL=ws://localhost:8765/telemetry     # Windows CMD

# Run
python main.py
```

#### Option B: 3D Enhanced Version ⭐ (Recommended)
```bash
cd "src backend"

# Enable WebSocket (Optional)
$env:CANSAT_WS_URL="ws://localhost:8765/telemetry"  # Windows PowerShell
# OR
set CANSAT_WS_URL=ws://localhost:8765/telemetry     # Windows CMD

# Run
python main_3d.py
```

**What happens:**
1. COM port selector dialog appears
2. Select your Ground Station ESP32 port
3. Click OK
4. GUI opens (2 windows for simple, 1 tabbed window for 3D)
5. Data starts flowing

**Look for this in console:**
```
✅ WebSocket publishing enabled: ws://localhost:8765/telemetry
🚀 CanSat Mission Control (3D) started!
📡 Serial Port: COM3
💾 Logging to: cansat_log_20251208_123456.csv
🌐 Streaming to: ws://localhost:8765/telemetry
T: 26.30 °C | Alt: 217.00 m | Acc: (0.10, 0.10, 9.80) | ...
```

✅ **Keep this running!** Don't close this terminal.

---

### 🔷 Step 3: Flutter Frontend (THIRD)

**Terminal/Command Prompt 3:**

```bash
cd "src frontend/src"

# Run on Windows
flutter run -d windows

# OR run on Android
flutter run -d android

# OR run on Chrome
flutter run -d chrome
```

**What happens:**
1. Flutter app compiles (takes ~30 seconds first time)
2. App launches
3. Connects to WebSocket at `ws://localhost:8765/telemetry`
4. Real-time data displays in beautiful UI

✅ **App is now running!**

---

## Visual Flow

```
┌─────────────────────┐
│  ESP32 CanSat       │
│  (Airborne)         │
│  - Sensors          │
│  - GPS              │
│  - IMU              │
└──────────┬──────────┘
           │ ESP-NOW
           ↓
┌─────────────────────┐
│  ESP32 Ground       │
│  Station (USB)      │
│  - Receives data    │
│  - Forwards serial  │
└──────────┬──────────┘
           │ USB Serial (115200 baud)
           ↓
┌─────────────────────────────────────────┐
│        STEP 2: Python Backend           │
│  Choose ONE:                            │
│  ┌───────────────┐  ┌────────────────┐ │
│  │  main.py      │  │  main_3d.py    │ │
│  │  (Simple)     │  │  (3D Enhanced) │ │
│  │  - 2 windows  │  │  - 1 window    │ │
│  │  - 2D dials   │  │  - 3D cylinder │ │
│  │  - Text only  │  │  - Real graphs │ │
│  └───────┬───────┘  └───────┬────────┘ │
│          └──────────────────┘           │
│                  │                      │
│                  ├─→ CSV Log           │
│                  ↓                      │
└──────────────────┬──────────────────────┘
                   │ WebSocket Client
                   ↓
┌─────────────────────────────────────────┐
│     STEP 1: WebSocket Relay             │
│     (relay.py)                          │
│     - ws://localhost:8765/telemetry     │
│     - Broadcasts to all clients         │
└──────────┬──────────────────────────────┘
           │ WebSocket Stream
           ↓
┌─────────────────────────────────────────┐
│     STEP 3: Flutter Frontend            │
│     - Windows Desktop App               │
│     - OR Android App                    │
│     - OR Web Browser                    │
│     - Beautiful UI                      │
│     - Real-time updates                 │
└─────────────────────────────────────────┘
```

---

## Quick Reference

| Step | Component | Run From | Command |
|------|-----------|----------|---------|
| **1** | WebSocket Relay | `websocket/` | `python relay.py` |
| **2A** | Backend (Simple) | `src backend/` | `python main.py` |
| **2B** | Backend (3D) | `src backend/` | `python main_3d.py` |
| **3** | Flutter Frontend | `src frontend/src/` | `flutter run -d windows` |

---

## Minimal Setup (Python Only)

If you don't want Flutter, just run:

**Option A (Simple):**
```bash
# No WebSocket needed
cd "src backend"
python main.py
```

**Option B (3D):**
```bash
# No WebSocket needed
cd "src backend"
python main_3d.py
```

This gives you:
- ✅ Live sensor display
- ✅ 3D visualization (if using main_3d.py)
- ✅ CSV logging
- ❌ No frontend app
- ❌ No WebSocket streaming

---

## Full Setup (All 3 Parts)

For complete system with frontend:

1. **Terminal 1:** `cd websocket` → `python relay.py`
2. **Terminal 2:** `cd "src backend"` → `python main_3d.py`
3. **Terminal 3:** `cd "src frontend/src"` → `flutter run -d windows`

---

## Environment Variables

### WebSocket URL
```bash
# Windows PowerShell
$env:CANSAT_WS_URL="ws://localhost:8765/telemetry"

# Windows CMD
set CANSAT_WS_URL=ws://localhost:8765/telemetry

# Linux/Mac
export CANSAT_WS_URL="ws://localhost:8765/telemetry"
```

### WebSocket Reconnect Delay
```bash
# Windows PowerShell
$env:CANSAT_WS_RECONNECT="5"

# Windows CMD  
set CANSAT_WS_RECONNECT=5

# Linux/Mac
export CANSAT_WS_RECONNECT=5
```

### Disable WebSocket
```bash
# Don't set CANSAT_WS_URL, or set it to empty:
$env:CANSAT_WS_URL=""
```

---

## Shutdown Order

**Reverse order is safest:**

1. **Close Flutter app** (Terminal 3) - Close window or Ctrl+C
2. **Close Python backend** (Terminal 2) - Close window or Ctrl+C
3. **Close WebSocket relay** (Terminal 1) - Ctrl+C

---

## Troubleshooting

### "Module not found" errors
```bash
pip install -r requirements_3d.txt
```

### "Port already in use"
- Close Arduino IDE
- Close Serial Monitor
- Unplug and replug ESP32

### WebSocket connection errors
- Make sure relay.py (Step 1) is running FIRST
- Check firewall isn't blocking port 8765

### Flutter won't connect
- Check WebSocket relay is running
- Check Python backend is streaming (you'll see "WebSocket publishing enabled")
- Try changing localhost to your PC's IP address

### ESP32 not sending data
- Check CANSAT.ino is uploaded and running
- Check GROUND_STATION.ino is uploaded and running
- Check ESP-NOW pairing is correct
- Check serial monitor on Ground Station shows data

---

## Success Indicators

### WebSocket Relay (Terminal 1)
```
✅ [INFO] cansat.websocket.relay: Relay ready (path=/telemetry)
✅ [INFO] cansat.websocket.relay: Client connected: 127.0.0.1:xxxxx
```

### Python Backend (Terminal 2)
```
✅ WebSocket publishing enabled: ws://localhost:8765/telemetry
✅ Serial Port: COM3
✅ Logging to: cansat_log_20251208_123456.csv
✅ T: 26.30 °C | Alt: 217.00 m | ... (updating continuously)
```

### Flutter Frontend (Terminal 3)
```
✅ Flutter application started
✅ Connected to 127.0.0.1:xxxxx
✅ (App shows live data updating)
```

---

**You're all set! Happy flying!** 🛰️🚀



