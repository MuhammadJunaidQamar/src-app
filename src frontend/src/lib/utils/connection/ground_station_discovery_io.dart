import 'dart:async';
import 'dart:io';

/// Must match GROUND_STATION_ROUTER.ino discovery port / magic.
const int kGsDiscoveryPort = 4210;
const String kGsDiscoveryMagic = 'CANSATGS';

/// Listen for UDP beacons from router ground stations on the LAN.
///
/// Payload: `CANSATGS|<ip>` (IP in the packet is preferred; sender address
/// is used as fallback).
Future<List<String>> discoverGroundStationHosts({
  Duration listenFor = const Duration(seconds: 3),
}) async {
  final hosts = <String>{};
  RawDatagramSocket? socket;

  try {
    socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      kGsDiscoveryPort,
      reuseAddress: true,
    );
    socket.broadcastEnabled = true;

    final sub = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = socket!.receive();
      if (dg == null) return;
      final text = String.fromCharCodes(dg.data).trim();
      if (!text.startsWith(kGsDiscoveryMagic)) return;

      String? ip;
      final parts = text.split('|');
      if (parts.length >= 2) {
        final candidate = parts[1].trim();
        if (_looksLikeIpv4(candidate)) ip = candidate;
      }
      ip ??= dg.address.address;
      if (_looksLikeIpv4(ip)) hosts.add(ip);
    });

    await Future<void>.delayed(listenFor);
    await sub.cancel();
  } catch (_) {
    // Binding can fail on some desktops if the port is taken; return what we have.
  } finally {
    socket?.close();
  }

  return hosts.toList()..sort();
}

bool _looksLikeIpv4(String s) {
  final parts = s.split('.');
  if (parts.length != 4) return false;
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null || n < 0 || n > 255) return false;
  }
  return true;
}
