# WebSocket Migration Guide

## Overview

The application has been migrated from HTTP REST API to WebSocket for real-time telemetry data streaming.

## Changes Made

### 1. **Dependencies Added**

- `web_socket_channel: ^3.0.1` - For WebSocket connectivity

### 2. **Constants Updated** (`lib/utils/constants/constants.dart`)

- Added `wsUrl` constant pointing to `ws://localhost:8765/telemetry`
- Platform-specific URLs:
  - Web: `ws://localhost:8765/telemetry`
  - Android: `ws://10.0.2.2:8765/telemetry`
  - Other platforms: `ws://localhost:8765/telemetry`

### 3. **ViewModel Completely Rewritten** (`lib/view_model/view_model.dart`)

#### Key Features:

- **Singleton Pattern**: Single WebSocket connection shared across the app
- **Auto-Reconnect**: Automatically reconnects after 3 seconds if connection drops
- **Stream-Based**: Real-time data streaming using Dart Streams
- **Backward Compatible**: Existing `fetchWorldStates()` method still works

#### New Architecture:

```dart
// Singleton instance with auto-connect
ViewModel()
  └─> _connect()
      ├─> WebSocketChannel.connect()
      ├─> Listen to stream
      │   ├─> Parse JSON
      │   ├─> Update _latestData
      │   └─> Broadcast to _dataController
      └─> Handle errors/disconnects
          └─> _handleDisconnect()
              └─> Auto-reconnect after 3s
```

## Usage

### Option 1: Use Existing API (Backward Compatible)

All existing code continues to work without changes:

```dart
final model = await ViewModel.fetchWorldStates('Temperature');
```

This method now:

1. Returns cached data if available (instant)
2. Waits for next WebSocket message if no cache (10s timeout)

### Option 2: Use Stream for Real-Time Updates (Recommended)

For continuous real-time updates:

```dart
final viewModel = ViewModel();

// Listen to real-time data stream
viewModel.dataStream.listen((model) {
  // Update UI with new data
  setState(() {
    this.model = model;
  });
});
```

### Option 3: Get Latest Cached Data

```dart
final viewModel = ViewModel();
final latestData = viewModel.latestData; // May be null
```

## WebSocket Server Requirements

Your WebSocket server at `ws://localhost:8765/telemetry` should:

1. **Accept connections** at `/telemetry` endpoint
2. **Send JSON messages** in this format:

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

**Field Mappings:**

- `temp` → Temperature (°C)
- `press` → Pressure (Pa)
- `alt` → Altitude (m)
- `ax, ay, az` → Acceleration X, Y, Z (m/s²)
- `gx, gy, gz` → Gyroscope/Rotation X, Y, Z (rad/s)
- `mx, my, mz` → Magnetometer X, Y, Z (μT)
- `head` → GPS Heading (degrees)
- `sat` → Number of GPS Satellites
- `lat` → GPS Latitude (degrees)
- `lon` → GPS Longitude (degrees)
- `gpsAlt` → GPS Altitude (m)

3. **Continuously stream** telemetry data (push model)
4. **Handle disconnections** gracefully (client will auto-reconnect)

**Note:** The Model class supports both the flat format (shown above) and the nested format from the old API, so migration is seamless.

## Benefits

### Real-Time Performance

- ✅ Continuous data streaming (no polling)
- ✅ Lower latency
- ✅ Reduced server load
- ✅ Efficient bandwidth usage

### Reliability

- ✅ Automatic reconnection on disconnect
- ✅ Error handling and logging
- ✅ Connection status monitoring
- ✅ Backward compatibility with existing code

### Developer Experience

- ✅ Singleton pattern - single connection
- ✅ Stream-based architecture
- ✅ Type-safe data models
- ✅ Debug logging in development mode

## Testing

### 1. Start WebSocket Server

```bash
# Your WebSocket server should be running on ws://localhost:8765/telemetry
```

### 2. Run Flutter App

```bash
flutter run
```

### 3. Monitor Connection

Check debug console for:

- `Connecting to WebSocket: ws://localhost:8765/telemetry`
- `Received WebSocket message: {...}`
- Connection status and any errors

## Troubleshooting

### Connection Issues

**Problem**: App can't connect to WebSocket
**Solution**:

- Ensure WebSocket server is running on port 8765
- Check firewall settings
- On Android emulator, use `10.0.2.2` instead of `localhost`

### Data Not Updating

**Problem**: No data received
**Solution**:

- Check WebSocket server is sending JSON in correct format
- Enable debug mode and check console logs
- Verify JSON field names match Model class

### Reconnection Loops

**Problem**: Constantly reconnecting
**Solution**:

- Check WebSocket server health
- Verify server stays alive and doesn't close connections immediately
- Check server logs for errors

## Advanced Usage

### Manual Reconnect

```dart
final viewModel = ViewModel();
viewModel.reconnect();
```

### Check Connection Status

```dart
final viewModel = ViewModel();
if (viewModel.isConnected) {
  print('Connected to WebSocket');
}
```

### Dispose (Optional)

```dart
// Only if you need to explicitly close connection
final viewModel = ViewModel();
viewModel.dispose();
```

## Migration Checklist

- [x] Add `web_socket_channel` dependency
- [x] Update Constants with WebSocket URL
- [x] Rewrite ViewModel with WebSocket support
- [x] Maintain backward compatibility
- [x] Add auto-reconnect feature
- [x] Install dependencies
- [x] Test for linter errors

## Next Steps

1. **Start your WebSocket server** on `ws://localhost:8765/telemetry`
2. **Run the app** and verify connection in debug console
3. **Optionally optimize widgets** to use stream-based updates instead of polling
4. **Monitor performance** and adjust reconnect timings if needed

---

**Note**: All existing code continues to work without any changes. The `fetchWorldStates()` method now uses WebSocket internally instead of HTTP.
