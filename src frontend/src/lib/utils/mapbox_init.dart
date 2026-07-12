import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:src/utils/secrets/secrets.dart';

/// True when a non-empty Mapbox access token is available for maps.
bool mapboxSdkConfigured = false;

/// Mapbox token for client-side maps (public `pk.` token).
String get mapboxAccessToken {
  const fromEnv = String.fromEnvironment('ACCESS_TOKEN');
  if (fromEnv.isNotEmpty) return fromEnv;
  return Secrets.mapboxPublicToken;
}

/// The native Mapbox SDK (`mapbox_maps_flutter`) only ships platform channels
/// for Android and iOS. On web and desktop, calling into it throws a
/// `channel-error` PlatformException, so those platforms use the WebView map.
bool get _supportsNativeMapbox =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Call once from [main]. Does not throw if the token is missing (maps show a placeholder).
void initMapboxSdk() {
  final token = mapboxAccessToken;
  if (token.isEmpty) {
    mapboxSdkConfigured = false;
    debugPrint(
      'Mapbox: no access token. Add mapboxPublicToken in secrets.dart or run with '
      '--dart-define=ACCESS_TOKEN=YOUR_MAPBOX_TOKEN',
    );
    return;
  }

  mapboxSdkConfigured = true;

  if (!_supportsNativeMapbox) {
    return;
  }

  mb.MapboxOptions.setAccessToken(token);
}
