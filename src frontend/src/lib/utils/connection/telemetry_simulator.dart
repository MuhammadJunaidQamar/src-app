import 'dart:math';

import 'package:src/model/model.dart';
import 'package:src/utils/mapbox_map_config.dart';

/// Generates realistic CanSat telemetry for demo / development without hardware.
class TelemetrySimulator {
  TelemetrySimulator();

  final _rng = Random();
  int _tick = 0;

  // Launch site matches the map default so the marker is visible immediately.
  static const _baseLat = MapboxMapConfig.defaultLatitude;
  static const _baseLon = MapboxMapConfig.defaultLongitude;
  static const _groundAltM = 220.0;
  static const _groundTempC = 22.0;
  static const _groundPressPa = 101200.0;

  Model nextSample() {
    _tick++;
    final t = _tick * 0.1; // 10 Hz

    // Ascent for ~50 s, then gentle descent.
    final phaseAlt = t < 50
        ? _groundAltM + t * 4.2
        : _groundAltM + 50 * 4.2 - (t - 50) * 1.8;
    final alt = phaseAlt + sin(t * 0.35) * 1.5;

    final temp =
        _groundTempC - (alt - _groundAltM) * 0.0065 + sin(t * 0.2) * 0.15;
    final press = _groundPressPa * exp(-(alt - _groundAltM) / 8500);
    // Sea-level reference (QNH) — stable baseline used for altitude math.
    final seaPress = _groundPressPa + sin(t * 0.05) * 8;

    final ax = sin(t * 2.1) * 0.35 + _noise(0.04);
    final ay = cos(t * 1.6) * 0.28 + _noise(0.04);
    final az = -9.81 + sin(t * 0.9) * 0.45 + _noise(0.03);

    final gx = sin(t * 1.1) * 0.09 + _noise(0.008);
    final gy = cos(t * 1.4) * 0.07 + _noise(0.008);
    final gz = sin(t * 0.6) * 0.04 + _noise(0.005);

    final mx = 24.0 + sin(t * 0.12) * 2.5;
    final my = -14.0 + cos(t * 0.15) * 2.0;
    final mz = 44.0 + sin(t * 0.08) * 1.5;

    final roll = sin(t * 0.55) * 0.18;
    final pitch = cos(t * 0.42) * 0.14;
    final yaw = t * 0.04;

    // Drift ~1.2 km over a minute along a gentle arc (visible on the map).
    final pathKm = t * 0.02;
    final heading = t * 0.08;
    final lat = _baseLat + (pathKm / 111.0) * cos(heading);
    final lon = _baseLon +
        (pathKm / (111.0 * cos(_baseLat * pi / 180))) * sin(heading);
    final head = (heading * 180 / pi + 360) % 360 - 180;
    final sats = min(12, 8 + (t / 15).floor());

    return Model(
      temperature: temp,
      pressure: press,
      altitude: alt,
      seaPressure: seaPress,
      acceleration: Acceleration(x: ax, y: ay, z: az),
      rotation: Rotation(x: gx, y: gy, z: gz),
      distance: Distance(x: mx, y: my, z: mz),
      gps: GPS(
        heading: head,
        noOfSatellites: sats,
        latitude: lat,
        longitude: lon,
        altitude: alt,
      ),
      roll: roll,
      pitch: pitch,
      yaw: yaw,
    );
  }

  double _noise(double amp) => (_rng.nextDouble() - 0.5) * 2 * amp;
}
