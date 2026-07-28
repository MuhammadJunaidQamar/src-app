import 'ground_station_discovery_stub.dart'
    if (dart.library.io) 'ground_station_discovery_io.dart' as impl;

/// Find router ground stations advertising on the LAN (UDP beacon).
Future<List<String>> discoverGroundStationHosts({
  Duration listenFor = const Duration(seconds: 3),
}) {
  return impl.discoverGroundStationHosts(listenFor: listenFor);
}
