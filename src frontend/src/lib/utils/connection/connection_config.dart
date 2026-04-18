import 'package:flutter/foundation.dart';

enum ConnectionMode {
  broadcast,
  directGroundStation,
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
    telemetryWsUrl: 'ws://192.168.4.1:8765/telemetry',
    cameraStreamUrl: 'http://192.168.4.1:81/stream',
  );

  static ConnectionMode? get selectedMode => _selectedMode;

  static bool get hasSelection => _selectedMode != null;

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
    if (mode == ConnectionMode.directGroundStation) {
      return _directEndpoints;
    }
    return ConnectionEndpoints(
      telemetryWsUrl: _defaultBroadcastWsUrl,
      cameraStreamUrl: _broadcastEndpoints.cameraStreamUrl,
    );
  }

  static String modeTitle(ConnectionMode mode) {
    switch (mode) {
      case ConnectionMode.broadcast:
        return 'Broadcast WebSocket';
      case ConnectionMode.directGroundStation:
        return 'Direct Ground Station';
    }
  }

  static String modeSubtitle(ConnectionMode mode) {
    if (mode == ConnectionMode.directGroundStation) {
      return 'Connect directly to the Ground Station AP (192.168.4.1).';
    }
    return 'Use the backend relay. Works with your existing server pipeline.';
  }

  static String get _defaultBroadcastWsUrl {
    if (kIsWeb) return 'ws://localhost:8765/telemetry';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'ws://10.0.2.2:8765/telemetry';
    }
    return 'ws://localhost:8765/telemetry';
  }
}
