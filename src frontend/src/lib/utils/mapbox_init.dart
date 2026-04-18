import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

/// True only after a non-empty `ACCESS_TOKEN` was applied via [initMapboxSdk].
bool mapboxSdkConfigured = false;

/// Call once from [main]. Does not throw if the token is missing (maps show a placeholder).
void initMapboxSdk() {
  const String token = String.fromEnvironment('ACCESS_TOKEN', defaultValue: '');
  if (token.isEmpty) {
    mapboxSdkConfigured = false;
    debugPrint(
      'Mapbox: no ACCESS_TOKEN. For maps, run with '
      '--dart-define=ACCESS_TOKEN=YOUR_MAPBOX_TOKEN',
    );
    return;
  }
  mb.MapboxOptions.setAccessToken(token);
  mapboxSdkConfigured = true;
}
