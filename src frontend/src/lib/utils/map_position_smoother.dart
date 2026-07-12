import 'dart:math' as math;

import 'package:src/utils/mapbox_map_config.dart';

/// Interruptible geographic chase: display lat/lng eases toward the latest GPS
/// target. New targets retarget from the current display position so motion
/// stays continuous (no snap/jitter) even at high telemetry rates.
class MapPositionSmoother {
  MapPositionSmoother({
    required double initialLatitude,
    required double initialLongitude,
  })  : displayLatitude = initialLatitude,
        displayLongitude = initialLongitude,
        _targetLatitude = initialLatitude,
        _targetLongitude = initialLongitude,
        _startLatitude = initialLatitude,
        _startLongitude = initialLongitude;

  double displayLatitude;
  double displayLongitude;

  double _targetLatitude;
  double _targetLongitude;
  double _startLatitude;
  double _startLongitude;

  DateTime _animStarted = DateTime.now();
  int _durationMs = MapboxMapConfig.followMinDurationMs;
  bool _animating = false;

  double get targetLatitude => _targetLatitude;
  double get targetLongitude => _targetLongitude;
  bool get isAnimating => _animating;

  /// Start (or restart) a chase toward [latitude]/[longitude].
  void setTarget(double latitude, double longitude, {bool snap = false}) {
    if (snap) {
      displayLatitude = latitude;
      displayLongitude = longitude;
      _targetLatitude = latitude;
      _targetLongitude = longitude;
      _startLatitude = latitude;
      _startLongitude = longitude;
      _animating = false;
      return;
    }

    _startLatitude = displayLatitude;
    _startLongitude = displayLongitude;
    _targetLatitude = latitude;
    _targetLongitude = longitude;

    final meters = _haversineMeters(
      _startLatitude,
      _startLongitude,
      _targetLatitude,
      _targetLongitude,
    );
    _durationMs = _durationForMeters(meters);
    _animStarted = DateTime.now();
    _animating = meters > 0.05;
    if (!_animating) {
      displayLatitude = latitude;
      displayLongitude = longitude;
    }
  }

  /// Advance the display position. Returns true if values changed.
  bool tick([DateTime? now]) {
    if (!_animating) return false;

    final elapsed =
        (now ?? DateTime.now()).difference(_animStarted).inMilliseconds;
    if (elapsed >= _durationMs) {
      displayLatitude = _targetLatitude;
      displayLongitude = _targetLongitude;
      _animating = false;
      return true;
    }

    final t = _easeOut(elapsed / _durationMs);
    displayLatitude = _lerp(_startLatitude, _targetLatitude, t);
    displayLongitude = _lerp(_startLongitude, _targetLongitude, t);
    return true;
  }

  static int _durationForMeters(double meters) {
    final raw = MapboxMapConfig.followMinDurationMs +
        (meters * MapboxMapConfig.followMsPerMeter).round();
    return raw.clamp(
      MapboxMapConfig.followMinDurationMs,
      MapboxMapConfig.followMaxDurationMs,
    );
  }

  static double _easeOut(double t) {
    final clamped = t.clamp(0.0, 1.0);
    final strength = MapboxMapConfig.followEaseStrength.clamp(0.0, 1.0);
    // Mix linear with cubic ease-out.
    final eased = 1 - math.pow(1 - clamped, 3).toDouble();
    return _lerp(clamped, eased, strength);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusM = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * earthRadiusM * math.asin(math.sqrt(a));
  }

  static double _toRad(double deg) => deg * math.pi / 180.0;
}
