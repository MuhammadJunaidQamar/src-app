import 'package:flutter/foundation.dart';

/// How the app reaches telemetry (and optionally camera).
/// Flash GS_ALL_PROTOCOLS.ino once; the app picks the transport at runtime.
enum ConnectionMode {
  /// Backend / relay WebSocket + optional remote MJPEG URL.
  /// Ground station sends USB Serial into the Python relay.
  broadcast,

  /// Phone joins the ground-station SoftAP (default SSID "CanSat-GS").
  directGroundStation,

  /// Ground station and phones join the same Wi‑Fi router; the app talks
  /// straight to the station over the LAN.
  routerGroundStation,

  /// Bluetooth GATT to the ground station.
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

  /// LAN IP of the ground station (router mode), from its Serial monitor.
  static String _routerHost = '';

  static String get routerHost => _routerHost;

  static void setRouterHost(String host) {
    _routerHost = host.trim();
  }

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

  static bool get usesBle => _selectedMode == ConnectionMode.bleGroundStation;

  static bool get usesSimulation => _selectedMode == ConnectionMode.simulation;

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
      case ConnectionMode.routerGroundStation:
        return ConnectionEndpoints(
          telemetryWsUrl: _routerHost.isEmpty ? '' : 'ws://$_routerHost:8765',
          // The router GS relays ESP-NOW camera packets as MJPEG on port 81.
          cameraStreamUrl:
              _routerHost.isEmpty ? '' : 'http://$_routerHost:81/stream',
        );
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
      case ConnectionMode.routerGroundStation:
        return 'Router (LAN) ground station';
      case ConnectionMode.bleGroundStation:
        return 'Bluetooth ground station';
      case ConnectionMode.simulation:
        return 'Simulation / demo';
    }
  }

  static String modeSubtitle(ConnectionMode mode) {
    switch (mode) {
      case ConnectionMode.broadcast:
        return 'WebSocket to your Python backend. Ground station feeds USB Serial into the relay.';
      case ConnectionMode.directGroundStation:
        return 'Phone joins the ground-station Wi‑Fi AP, then pairs with the 6-digit Serial code.';
      case ConnectionMode.routerGroundStation:
        return 'Station and phones join the same Wi‑Fi router. Enter only the 6-digit Serial code — the app finds your station on the LAN.';
      case ConnectionMode.bleGroundStation:
        return 'Pick your station in the list, then pair with the 6-digit Serial code.';
      case ConnectionMode.simulation:
        return 'Explore the dashboard with realistic dummy CanSat telemetry — no ESP32 or pairing needed.';
    }
  }

  /// Short colored tip under each mode card (not a flash path — one sketch covers all).
  static String firmwareHint(ConnectionMode mode) {
    switch (mode) {
      case ConnectionMode.broadcast:
        return 'USB Serial → Python relay → WebSocket'; //!needs work
      case ConnectionMode.directGroundStation:
        return 'Join AP "CanSat-GS" (or your GS_AP_SSID) · enter code';
      case ConnectionMode.routerGroundStation:
        return 'Same Wi‑Fi as station · set GS_STA_SSID · enter code';
      case ConnectionMode.bleGroundStation:
        return 'Select station in list · enter 6-digit Serial code';
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
