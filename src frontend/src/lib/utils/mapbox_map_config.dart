/// Shared Mapbox settings for native (mobile) and WebView (desktop) maps.
class MapboxMapConfig {
  static const styleUri =
      'mapbox://styles/university-of-central-punjab/cm1v3ghd9016b01pe3gmwb9g4';

  // Matches the style import config from the mobile map style.
  static const basemapLightPreset = 'dusk';
  static const basemapTheme = 'default';
  static const basemapShow3dObjects = true;

  static const defaultLatitude = 31.4469;
  static const defaultLongitude = 74.2682;

  static const cameraZoom = 17.0;
  static const cameraPitch = 30.0;
  static const cameraBearing = 0.0;

  /// Desktop WebView fly/ease duration (ms). Shorter = snappier recenter.
  static const recenterFlyDurationMs = 1200;

  /// Smooth chase of the latest GPS sample (marker + camera lock together).
  /// Duration scales with distance so large jumps ease slowly instead of snapping.
  static const followMinDurationMs = 450;
  static const followMaxDurationMs = 2800;
  /// Extra ms per meter of geographic gap (clamped by min/max above).
  static const followMsPerMeter = 18.0;
  /// Soften each hop: 0 = linear, 1 = strong ease-out.
  static const followEaseStrength = 0.85;

  static const satelliteIconUrl =
      'http://localhost:8080/icons/satellite.png';
}
