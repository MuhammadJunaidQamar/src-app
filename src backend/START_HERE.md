# 🚀 Quick Start Guide

## You Now Have 3D Visualization! ⭐

I've added the **3D rotating cylinder** from `temp new` into your stable `src backend`.

---

## Choose Your Version:

### **Option 1: Simple Version** (Fast & Stable)
```bash
cd "src backend"
python main.py
```
- 2 windows (Main + Gyro)
- 2D circular dials
- Lightweight

### **Option 2: 3D Enhanced Version** (Full Features!) ⭐
```bash
cd "src backend"
python main_3d.py
```
- **3D rotating cylinder!**
- Beautiful tabbed UI
- Real-time graphs for ALL sensors
- Shows roll, pitch, yaw, distance

---

## First Time Setup

### Install Dependencies:
```bash
cd "src backend"
pip install -r requirements_3d.txt
```

Or manually:
```bash
pip install pyserial websockets pillow numpy matplotlib
```

---

## Complete System (All 3 Parts):

### Terminal 1: WebSocket Relay
```bash
cd websocket
python relay.py
```

### Terminal 2: Backend (Choose One)

**Simple:**
```bash
cd "src backend"
$env:CANSAT_WS_URL="ws://localhost:8765/telemetry"
python main.py
```

**3D (Recommended):**
```bash
cd "src backend"
$env:CANSAT_WS_URL="ws://localhost:8765/telemetry"
python main_3d.py
```

### Terminal 3: Flutter Frontend
```bash
cd "src frontend/src"
flutter run -d windows
```

---

## What's New in 3D Version?

✅ **3D Rotating Cylinder** - Shows real-time orientation  
✅ **Real-time Graphs** - For all 18 sensors  
✅ **Roll/Pitch/Yaw Display** - From your ESP32 updates  
✅ **Distance Tracking** - Current and total distance graphs  
✅ **Modern Dark Theme** - Beautiful UI  
✅ **Tabbed Interface** - Organized and clean  
✅ **Needle Dials** - 3 circular gauges for angles  

All while keeping:
✅ **WebSocket Support** - Streams to frontend  
✅ **CSV Logging** - All data saved  
✅ **Stability** - No blue screen bugs from temp new  
✅ **Your ESP32 Updates** - Works with new packet structure  

---

## Troubleshooting

**No 3D display?**
- Make sure matplotlib is installed: `pip install matplotlib`

**Import errors?**
```bash
pip install numpy matplotlib
```

**Too slow?**
- Use `main.py` instead (simple version)

**Serial port errors?**
- Check ESP32 is connected
- Select correct COM port from dialog

---

## Next Steps

1. ✅ Upload `CANSAT.ino` to CanSat ESP32
2. ✅ Upload `GROUND_STATION.ino` to Ground Station ESP32
3. ✅ Run `main_3d.py` (or `main.py` for simple)
4. ✅ (Optional) Run `relay.py` for WebSocket
5. ✅ (Optional) Run Flutter frontend

---

## Need More Info?

Read `README_3D.md` for full documentation.

**Enjoy your 3D CanSat Ground Station!** 🛰️✨



