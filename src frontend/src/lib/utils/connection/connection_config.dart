import 'package:flutter/foundation.dart';

/// How the app reaches telemetry (and optionally camera).
/// Flash the matching ESP32 firmware before use — see [firmwareHint].
enum ConnectionMode {
  /// Backend / relay WebSocket + optional remote MJPEG URL.
  broadcast,

  /// Phone joins ground-station Wi‑Fi AP — flash GROUND_STATION.ino.
  directGroundStation,

  /// Bluetooth — flash GROUND_STATION_BLE.ino.
  bleGroundStation,

  /// Built-in demo telemetry — no hardware required.
  simulation,
}

class ConnectionEndpoints {
  const ConnectionEndpoints({
    required this.telemetryWsUrl,
    required this.cameraStreamUrl,
  });

  final String telemetryWsUrl;
  final String cameraStreamUrl;
}

class ConnectionConfig {
  ConnectionConfig._();

  static ConnectionMode? _selectedMode;

  static const ConnectionEndpoints _broadcastEndpoints = ConnectionEndpoints(
    telemetryWsUrl: '',
    cameraStreamUrl: 'http://10.8.172.190:81/stream',
  );

  static const ConnectionEndpoints _directEndpoints = ConnectionEndpoints(
    telemetryWsUrl: 'ws://192.168.4.1:8765',
    cameraStreamUrl: 'http://192.168.4.1:81/stream',
  );

  static const ConnectionEndpoints _bleEndpoints = ConnectionEndpoints(
    telemetryWsUrl: '',
    cameraStreamUrl: '',
  );

  static ConnectionMode? get selectedMode => _selectedMode;

  static bool get hasSelection => _selectedMode != null;

  static bool get usesBle =>
      _selectedMode == ConnectionMode.bleGroundStation;

  static bool get usesSimulation =>
      _selectedMode == ConnectionMode.simulation;

  static bool get usesWebSocket =>
      _selectedMode != null && !usesBle && !usesSimulation;

  static bool get usesMjpegCamera {
    if (_selectedMode == null) return false;
    if (usesBle || usesSimulation) return false;
    return selectedEndpoints.cameraStreamUrl.isNotEmpty;
  }

  static bool get usesBleCamera => usesBle;

  static void selectMode(ConnectionMode mode) {
    _selectedMode = mode;
  }

  static void resetSelection() {
    _selectedMode = null;
  }

  static ConnectionEndpoints get selectedEndpoints {
    if (_selectedMode == null) {
      throw StateError('Connection mode must be selected before use.');
    }
    return endpointsFor(_selectedMode!);
  }

  static ConnectionEndpoints endpointsFor(ConnectionMode mode) {
    switch (mode) {
      case ConnectionMode.broadcast:
        return ConnectionEndpoints(
          telemetryWsUrl: _defaultBroadcastWsUrl,
          cameraStreamUrl: _broadcastEndpoints.cameraStreamUrl,
        );
      case ConnectionMode.directGroundStation:
        return _directEndpoints;
      case ConnectionMode.bleGroundStation:
        return _bleEndpoints;
      case ConnectionMode.simulation:
        return const ConnectionEndpoints(
          telemetryWsUrl: '',
          cameraStreamUrl: '',
        );
    }
  }

  static String modeTitle(ConnectionMode mode) {
    switch (mode) {
      case ConnectionMode.broadcast:
        return 'Broadcast / server';
      case ConnectionMode.directGroundStation:
        return 'Wi‑Fi ground station';
      case ConnectionMode.bleGroundStation:
        return 'Bluetooth ground station';
      case ConnectionMode.simulation:
        return 'Simulation / demo';
    }
  }

  static String modeSubtitle(ConnectionMode mode) {
    switch (mode) {
      case ConnectionMode.broadcast:
        return 'WebSocket to your backend relay. Camera via configured stream URL.';
      case ConnectionMode.directGroundStation:
        return 'Join AP "CanSat-GS", enter the 6-digit code from Serial. Flash GROUND_STATION.ino.';
      case ConnectionMode.bleGroundStation:
        return 'Pick your station in the list, enter the 6-digit Serial code. Flash GROUND_STATION_BLE.ino.';
      case ConnectionMode.simulation:
        return 'Explore the dashboard with realistic dummy CanSat telemetry — no ESP32 or pairing needed.';
    }
  }

  static String firmwareHint(ConnectionMode mode) {
    switch (mode) {
      case ConnectionMode.broadcast:
        return 'No ESP32 GS firmware required for this app link.';
      case ConnectionMode.directGroundStation:
        return 'Flash: esp32/GROUND_STATION/GROUND_STATION.ino';
      case ConnectionMode.bleGroundStation:
        return 'Flash: esp32/GROUND_STATION_BLE/GROUND_STATION_BLE.ino';
      case ConnectionMode.simulation:
        return 'No hardware or firmware required.';
    }
  }

  static bool isModeSupportedOnPlatform(ConnectionMode mode) {
    // BLE on web is served by the endorsed flutter_blue_plus_web backend (Web
    // Bluetooth API). It only works in Chromium browsers over HTTPS/localhost,
    // so availability is verified at scan time; the mode itself is offered.
    return true;
  }

  static String get _defaultBroadcastWsUrl {
    if (kIsWeb) return 'ws://localhost:8765';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'ws://10.0.2.2:8765';
    }
    return 'ws://localhost:8765';
  }
}
