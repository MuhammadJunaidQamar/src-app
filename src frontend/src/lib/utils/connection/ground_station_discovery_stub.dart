/// Web / non-IO platforms cannot listen for LAN UDP beacons.
Future<List<String>> discoverGroundStationHosts({
  Duration listenFor = const Duration(seconds: 3),
}) async {
  return const [];
}
