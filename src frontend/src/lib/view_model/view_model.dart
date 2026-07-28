import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:src/model/model.dart';
import 'package:src/utils/connection/connection_config.dart';
import 'package:src/utils/connection/ground_station_discovery.dart';
import 'package:src/utils/connection/telemetry_simulator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ── BLE UUIDs (GROUND_STATION_BLE.ino) ───────────────────────────────────────
const _kNusService = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const _kNusTx = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';
const _kNusRx = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
const _kCamService = '6e400010-b5a3-f393-e0a9-e50e24dcca9e';
const _kCamTx = '6e400011-b5a3-f393-e0a9-e50e24dcca9e';

/// WinRT reports 16-bit UUID aliases (e.g. `0011`) while discovery uses 128-bit strings.
String _bleUuidKey(String uuid) {
  final u = uuid.toLowerCase().replaceAll('-', '');
  if (u.length == 4) return u;
  final dash = uuid.toLowerCase().indexOf('-');
  final head = dash > 0 ? uuid.toLowerCase().substring(0, dash) : uuid.toLowerCase();
  return head.length >= 4 ? head.substring(head.length - 4) : head;
}

bool _bleUuidMatches(String a, String b) => _bleUuidKey(a) == _bleUuidKey(b);

enum BleStatus { idle, scanning, connecting, connected, disconnected, error }

enum LinkStatus { idle, connecting, connected, disconnected, error }

/// WinRT BLE (flutter_blue_plus_winrt) needs a slower GATT sequence than Android.
bool get _bleUseWinrtDesktop {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows;
}

class ViewModel {
  static ViewModel? _instance;

  factory ViewModel() {
    _instance ??= ViewModel._internal();
    return _instance!;
  }

  ViewModel._internal() {
    _ensureDataController();
  }

  // ── Shared ───────────────────────────────────────────────────────────────────
  BleStatus bleStatus = BleStatus.idle;
  LinkStatus linkStatus = LinkStatus.idle;
  String? linkError;
  String? connectedDeviceName;

  StreamController<Model>? _dataController;
  StreamController<Uint8List>? _cameraController;
  Model? _latestData;

  Timer? _reconnectTimer;
  bool _linkPaired = false;

  // ── Simulation ───────────────────────────────────────────────────────────────
  Timer? _simulationTimer;
  final TelemetrySimulator _simulator = TelemetrySimulator();
  bool _simulationActive = false;

  // ── WebSocket (Wi‑Fi / broadcast) ───────────────────────────────────────────
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  bool _wsConnected = false;
  String? _activeWsUrl;

  // ── BLE ──────────────────────────────────────────────────────────────────────
  BluetoothDevice? _device;
  BluetoothCharacteristic? _txChar;
  BluetoothCharacteristic? _rxChar;
  BluetoothCharacteristic? _camChar;
  List<BluetoothService>? _bleServices;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BmCharacteristicData>? _telemPlatformSub;
  StreamSubscription<List<int>>? _camNotifySub;
  StreamSubscription<BmCharacteristicData>? _camPlatformSub;
  Timer? _camReadPollTimer;
  bool _camReadInFlight = false;
  int _camReadAttempts = 0;
  int get camReadAttempts => _camReadAttempts;

  /// Last successful 6-digit pairing code (re-sent on BLE reconnect).
  String? _blePairDigits;

  /// While true, ignore transient disconnects during pair (WinRT drops link mid-GATT).
  bool _blePairingInProgress = false;

  final StringBuffer _rxBuffer = StringBuffer();
  final Map<int, Uint8List> _camChunks = {};
  int _camExpectedChunks = 0;
  int _camCurrentFrame = -1;
  int _camChunksReceived = 0;
  int get camChunksReceived => _camChunksReceived;

  int _camDedupeKey = -1;
  int _camDedupeMs = 0;

  void _ensureDataController() {
    if (_dataController == null || _dataController!.isClosed) {
      _dataController = StreamController<Model>.broadcast();
    }
    if (_cameraController == null || _cameraController!.isClosed) {
      _cameraController = StreamController<Uint8List>.broadcast();
    }
  }

  Stream<Model> get dataStream => _dataController!.stream;
  Stream<Uint8List> get cameraStream => _cameraController!.stream;
  Model? get latestData => _latestData;

  /// True when the ground station exposed the BLE camera notify characteristic.
  bool get bleCameraAvailable => _camChar != null;

  bool get bleCameraNotifying => _camChar?.isNotifying ?? false;

  int _bleCameraFrameCount = 0;
  int get bleCameraFrameCount => _bleCameraFrameCount;

  int _bleCameraNotifyCount = 0;
  int get bleCameraNotifyCount => _bleCameraNotifyCount;

  int _bleCameraLastNotifyBytes = 0;
  int get bleCameraLastNotifyBytes => _bleCameraLastNotifyBytes;

  bool get isConnected {
    if (ConnectionConfig.usesSimulation) return _simulationActive;
    if (!_linkPaired && !ConnectionConfig.usesWebSocket) return false;
    if (ConnectionConfig.usesBle) {
      return bleStatus == BleStatus.connected && _linkPaired;
    }
    return _wsConnected && _linkPaired;
  }

  bool get isLinkPaired => _linkPaired;

  /// Scan for ground stations (BLE). Call [stopBleScan] when done.
  ///
  /// On web there is no passive scan: [FlutterBluePlus.startScan] opens the
  /// browser's device chooser (Web Bluetooth), so it MUST be invoked from a
  /// user gesture and MUST declare the services we intend to use, otherwise the
  /// firmware's GATT services are inaccessible after connecting.
  Future<void> startBleDiscovery() async {
    await _stopBleScan();
    if (kIsWeb) {
      await FlutterBluePlus.startScan(
        withServices: [Guid(_kNusService), Guid(_kCamService)],
      );
      return;
    }
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 8),
    );
  }

  /// Live scan results while [startBleDiscovery] is running.
  Stream<List<ScanResult>> get bleScanResults => FlutterBluePlus.scanResults;

  Future<void> stopBleDiscovery() => _stopBleScan();

  void _resetBleGattState() {
    _txChar = null;
    _rxChar = null;
    _camChar = null;
    _bleServices = null;
  }

  Future<List<BluetoothService>> _discoverBleServices(
    BluetoothDevice device, {
    bool force = false,
    bool forPairing = false,
  }) async {
    if (!force && _bleServices != null && _bleServices!.isNotEmpty) {
      return _bleServices!;
    }
    _bleServices = await device.discoverServices();
    if (_bleUseWinrtDesktop && forPairing) {
      await Future.delayed(const Duration(milliseconds: 80));
    } else {
      await _bleGattPause();
    }
    return _bleServices!;
  }

  void _resolveBleCharacteristics(List<BluetoothService> services) {
    final nusService = services
        .where((s) => _bleUuidMatches(s.serviceUuid.str, _kNusService))
        .firstOrNull;
    if (nusService != null) {
      for (final c in nusService.characteristics) {
        final uuid = c.characteristicUuid.str.toLowerCase();
        if (_bleUuidMatches(uuid, _kNusTx)) _txChar = c;
        if (_bleUuidMatches(uuid, _kNusRx)) _rxChar = c;
      }
    }

    final camService = services
        .where((s) => _bleUuidMatches(s.serviceUuid.str, _kCamService))
        .firstOrNull;
    if (camService != null) {
      _camChar = camService.characteristics
          .where((c) => _bleUuidMatches(c.characteristicUuid.str, _kCamTx))
          .firstOrNull;
    }
  }

  Future<void> _bleGattPause([Duration? desktopDelay]) async {
    if (!_bleUseWinrtDesktop) return;
    await Future.delayed(desktopDelay ?? const Duration(milliseconds: 280));
  }

  Future<void> _bleConnectDevice(
    BluetoothDevice device, {
    bool forPairing = false,
  }) async {
    await _stopBleScan();
    final timeout = _bleUseWinrtDesktop
        ? const Duration(seconds: 20)
        : const Duration(seconds: 12);
    // flutter_blue_plus defaults connect(mtu: 512), which negotiates MTU during
    // the connection handshake. On WinRT that MTU negotiation frequently drops
    // the link immediately (Connected → Disconnected before any GATT op). Pass
    // mtu: null on Windows so no MTU is requested during connect; we negotiate
    // it (best-effort) only after pairing succeeds.
    if (_bleUseWinrtDesktop) {
      await device.connect(
        license: License.free,
        timeout: timeout,
        mtu: null,
      );
    } else {
      await device.connect(license: License.free, timeout: timeout);
    }
    if (_bleUseWinrtDesktop && forPairing) {
      await Future.delayed(const Duration(milliseconds: 120));
    } else {
      await _bleGattPause(const Duration(milliseconds: 450));
    }
  }

  Future<void> _bleRequestMtu(BluetoothDevice device) async {
    // Match Android: large MTU so 6+244 byte camera notifies are not truncated.
    try {
      await device.requestMtu(512);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BLE] MTU 512 negotiate failed: $e');
      }
      if (_bleUseWinrtDesktop) {
        try {
          await device.requestMtu(247);
        } catch (_) {}
      }
    }
    await _bleGattPause(
      Duration(milliseconds: _bleUseWinrtDesktop ? 200 : 80),
    );
  }

  /// Subscribe to telemetry/pair notifications from the NUS TX characteristic.
  ///
  /// On WinRT the per-characteristic [onValueReceived] stream is unreliable, so
  /// we mirror the camera path and also listen on the platform-level notify
  /// stream. Without this, the `{"pair":"ok"}` reply never reaches the app on
  /// Windows and pairing always times out.
  Future<void> _listenTelemetryNotify(
    BluetoothDevice device, {
    void Function()? onPairOk,
    void Function()? onPairFail,
  }) async {
    await _notifySub?.cancel();
    await _telemPlatformSub?.cancel();
    _telemPlatformSub = null;

    _notifySub = _txChar!.onValueReceived.listen((bytes) {
      _handleBleNotify(bytes, onPairOk: onPairOk, onPairFail: onPairFail);
    });

    if (_bleUseWinrtDesktop) {
      final remoteIdStr = device.remoteId.str.toLowerCase();
      _telemPlatformSub = FlutterBluePlusPlatform.instance.onCharacteristicReceived
          .where((p) => p.success)
          .listen((p) {
        final sameDevice = p.remoteId.str.toLowerCase() == remoteIdStr;
        final isTelem = _bleUuidMatches(p.characteristicUuid.str, _kNusTx);
        if (sameDevice && isTelem) {
          _handleBleNotify(p.value, onPairOk: onPairOk, onPairFail: onPairFail);
        }
      });
    }
  }

  void _listenBleConnection(
    BluetoothDevice device, {
    void Function()? onDisconnectedDuringPairing,
  }) {
    _connSub?.cancel();
    _connSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        if (_blePairingInProgress) {
          if (kDebugMode) {
            debugPrint('[BLE] Disconnect during pairing (fail fast)');
          }
          onDisconnectedDuringPairing?.call();
          return;
        }
        _handleBleDisconnect();
      }
    });
  }

  Future<void> _writePairCode(String digits, {bool preferWithoutResponse = false}) async {
    final payload = utf8.encode('PAIR:$digits');
    if (preferWithoutResponse) {
      try {
        await _rxChar!.write(payload, withoutResponse: true);
        if (kDebugMode) debugPrint('[BLE pair] wrote PAIR (without response)');
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[BLE pair] write NR failed ($e); retrying with response');
        }
        await _rxChar!.write(payload);
        if (kDebugMode) debugPrint('[BLE pair] wrote PAIR (with response)');
      }
    } else {
      try {
        await _rxChar!.write(payload);
        if (kDebugMode) debugPrint('[BLE pair] wrote PAIR (with response)');
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[BLE pair] write-with-response failed ($e); retrying NR');
        }
        await _rxChar!.write(payload, withoutResponse: true);
        if (kDebugMode) debugPrint('[BLE pair] wrote PAIR (without response)');
      }
    }
    if (_bleUseWinrtDesktop) {
      await Future.delayed(const Duration(milliseconds: 120));
    } else {
      await _bleGattPause(const Duration(milliseconds: 350));
    }
  }

  /// WinRT drops the link if GATT setup is too slow. Pair with minimal steps:
  /// connect → discover → notify → write PAIR (no MTU until after success).
  Future<bool> _pairBleDeviceWinrt(BluetoothDevice device, String digits) async {
    const attempts = 3;
    for (var attempt = 0; attempt < attempts; attempt++) {
      if (attempt > 0 && kDebugMode) {
        debugPrint('[BLE] Pair retry ${attempt + 1}/$attempts (Windows)');
      }

      _setBle(BleStatus.connecting);
      _device = device;
      _blePairingInProgress = true;
      _resetBleGattState();

      Completer<bool>? completer;
      try {
        completer = Completer<bool>();
        Timer? timeout;

        if (kDebugMode) {
          debugPrint('[BLE pair] connecting to ${device.remoteId.str}…');
        }
        await _bleConnectDevice(device, forPairing: true);
        _listenBleConnection(
          device,
          onDisconnectedDuringPairing: () {
            if (completer != null && !completer.isCompleted) {
              completer.complete(false);
            }
          },
        );

        if (kDebugMode) debugPrint('[BLE pair] discovering services (fast)…');
        final services = await _discoverBleServices(
          device,
          force: true,
          forPairing: true,
        );
        _resolveBleCharacteristics(services);
        if (_txChar == null || _rxChar == null) {
          throw Exception('NUS characteristics not found');
        }

        await _listenTelemetryNotify(
          device,
          onPairOk: () {
            if (!completer!.isCompleted) completer.complete(true);
          },
          onPairFail: () {
            if (!completer!.isCompleted) completer.complete(false);
          },
        );

        if (kDebugMode) debugPrint('[BLE pair] enabling notify…');
        await _txChar!.setNotifyValue(true);
        await Future.delayed(const Duration(milliseconds: 80));

        if (kDebugMode) debugPrint('[BLE pair] writing PAIR code…');
        await _writePairCode(digits, preferWithoutResponse: true);

        timeout = Timer(const Duration(seconds: 8), () {
          if (!completer!.isCompleted) {
            if (kDebugMode) debugPrint('[BLE pair] TIMEOUT (no pair reply)');
            completer.complete(false);
          }
        });

        final ok = await completer.future;
        timeout.cancel();
        if (kDebugMode) debugPrint('[BLE pair] result=$ok');

        if (ok) {
          _blePairDigits = digits;
          _linkPaired = true;
          connectedDeviceName = device.platformName;
          _setBle(BleStatus.connected);
          _setLink(LinkStatus.connected);
          // Windows negotiates ATT MTU automatically at the OS level, so we do
          // NOT request it manually here — an explicit requestMtu can drop the
          // freshly-paired link on WinRT.
          if (kDebugMode) debugPrint('[BLE pair] paired; subscribing camera…');
          await _subscribeBleCamera(device);
          return true;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[BLE pair] attempt ${attempt + 1}: $e');
        }
        if (completer != null && !completer.isCompleted) {
          completer.complete(false);
        }
      } finally {
        _blePairingInProgress = false;
      }

      if (attempt < attempts - 1) {
        await _disconnectBle();
        await Future.delayed(const Duration(milliseconds: 1200));
      }
    }

    await _disconnectBle();
    _setBle(BleStatus.error, 'Pairing failed');
    return false;
  }

  /// Connect to [device] and verify [code] (6 digits). Returns true if paired.
  Future<bool> pairBleDevice(BluetoothDevice device, String code) async {
    _reconnectTimer?.cancel();
    await _disconnectBle();

    final digits = code.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 6) return false;

    if (_bleUseWinrtDesktop) {
      return _pairBleDeviceWinrt(device, digits);
    }

    const attempts = 1;
    for (var attempt = 0; attempt < attempts; attempt++) {
      _setBle(BleStatus.connecting);
      _device = device;
      _blePairingInProgress = true;
      _resetBleGattState();

      Completer<bool>? completer;
      try {
        completer = Completer<bool>();
        Timer? timeout;

        if (kDebugMode) debugPrint('[BLE pair] connecting to ${device.remoteId.str}…');
        await _bleConnectDevice(device);
        _listenBleConnection(
          device,
          onDisconnectedDuringPairing: () {
            if (completer != null && !completer.isCompleted) {
              completer.complete(false);
            }
          },
        );

        await _bleRequestMtu(device);
        await _bleGattPause();

        final services = await _discoverBleServices(device, force: true);
        _resolveBleCharacteristics(services);
        if (_txChar == null || _rxChar == null) {
          throw Exception('NUS characteristics not found');
        }

        await _listenTelemetryNotify(
          device,
          onPairOk: () {
            if (!completer!.isCompleted) completer.complete(true);
          },
          onPairFail: () {
            if (!completer!.isCompleted) completer.complete(false);
          },
        );

        await _txChar!.setNotifyValue(true);
        await _bleGattPause(const Duration(milliseconds: 300));

        await _writePairCode(digits);

        timeout = Timer(const Duration(seconds: 8), () {
          if (!completer!.isCompleted) completer.complete(false);
        });

        final ok = await completer.future;
        timeout.cancel();

        if (ok) {
          _blePairDigits = digits;
          _linkPaired = true;
          connectedDeviceName = device.platformName;
          _setBle(BleStatus.connected);
          _setLink(LinkStatus.connected);
          await _subscribeBleCamera(device);
          return true;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[BLE pair] attempt ${attempt + 1}: $e');
        }
        if (completer != null && !completer.isCompleted) {
          completer.complete(false);
        }
      } finally {
        _blePairingInProgress = false;
      }
    }

    await _disconnectBle();
    _setBle(BleStatus.error, 'Pairing failed');
    return false;
  }

  /// Verify the 6-digit code at http://<host>/pair.
  ///
  /// Wi‑Fi AP mode uses the fixed SoftAP address (192.168.4.1). Router (LAN)
  /// mode usually finds the host via [pairRouterWithCode] (UDP discovery).
  Future<bool> pairWifiWithCode(String code, {String host = '192.168.4.1'}) async {
    final digits = code.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 6) return false;

    try {
      final uri = Uri.parse('http://$host/pair?code=$digits');
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      final ok = resp.statusCode == 200 && resp.body.contains('"pair":"ok"');
      if (ok) {
        _linkPaired = true;
        if (kDebugMode) debugPrint('[WiFi] Pairing OK ($host)');
      }
      return ok;
    } catch (e) {
      if (kDebugMode) debugPrint('[WiFi pair] $host: $e');
      return false;
    }
  }

  /// Router mode: discover stations on the LAN, then pair with the one that
  /// accepts [code]. Returns the matched host IP, or null on failure.
  ///
  /// Optional [manualHost] skips discovery (fallback / web).
  Future<String?> pairRouterWithCode(
    String code, {
    String? manualHost,
  }) async {
    final digits = code.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 6) return null;

    final hosts = <String>[];
    final manual = manualHost?.trim();
    if (manual != null && manual.isNotEmpty) {
      hosts.add(manual);
    } else {
      if (kDebugMode) debugPrint('[Router] Discovering ground stations…');
      final found = await discoverGroundStationHosts(
        listenFor: const Duration(seconds: 3),
      );
      hosts.addAll(found);
      final known = ConnectionConfig.routerHost.trim();
      if (known.isNotEmpty && !hosts.contains(known)) {
        hosts.add(known);
      }
    }

    if (hosts.isEmpty) {
      if (kDebugMode) debugPrint('[Router] No stations discovered');
      return null;
    }

    if (kDebugMode) debugPrint('[Router] Trying hosts: $hosts');
    for (final host in hosts) {
      final ok = await pairWifiWithCode(digits, host: host);
      if (ok) {
        ConnectionConfig.setRouterHost(host);
        return host;
      }
      // Wrong code on this host — keep looking (other teams' stations).
      _linkPaired = false;
    }
    return null;
  }

  /// Start built-in demo telemetry (no hardware).
  void startSimulation() {
    if (!ConnectionConfig.usesSimulation) return;

    _reconnectTimer?.cancel();
    _disconnectWebSocket();
    _disconnectBle();
    _ensureDataController();

    _linkPaired = true;
    _simulationActive = true;
    connectedDeviceName = 'Simulation';
    _setLink(LinkStatus.connected);
    _setBle(BleStatus.idle);

    _simulationTimer?.cancel();
    _emitSimulationSample();
    _simulationTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _emitSimulationSample(),
    );

    if (kDebugMode) debugPrint('[Sim] Demo telemetry started');
  }

  void _emitSimulationSample() {
    final model = _simulator.nextSample();
    _latestData = model;
    _dataController?.add(model);
  }

  void _stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _simulationActive = false;
  }

  /// Start telemetry link after successful pairing (Wi‑Fi / broadcast).
  void connectWithSelectedMode() {
    if (!ConnectionConfig.hasSelection) {
      if (kDebugMode) {
        debugPrint('[Link] No connection mode selected.');
      }
      return;
    }

    _reconnectTimer?.cancel();

    if (ConnectionConfig.usesSimulation) {
      startSimulation();
      return;
    }

    _stopSimulation();

    if (ConnectionConfig.usesBle) {
      return; // BLE: connected via [pairBleDevice]
    }

    _disconnectBle();
    _disconnectWebSocket();

    if (ConnectionConfig.selectedMode == ConnectionMode.broadcast) {
      _linkPaired = true;
    }

    if (!_linkPaired) {
      if (kDebugMode) debugPrint('[Link] Pair before connecting.');
      return;
    }

    final url = ConnectionConfig.selectedEndpoints.telemetryWsUrl;
    if (url.isEmpty) {
      _setLink(LinkStatus.error, 'Telemetry WebSocket URL is empty.');
      return;
    }
    _connectWebSocket(url);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WebSocket
  // ═══════════════════════════════════════════════════════════════════════════

  void _connectWebSocket(String url) {
    if (_wsConnected && _activeWsUrl == url) return;

    _disconnectWebSocket();
    _activeWsUrl = url;
    _setLink(LinkStatus.connecting);
    _setBle(BleStatus.idle);

    if (kDebugMode) debugPrint('[WS] Connecting to $url');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _wsSub = _channel!.stream.listen(
        _onWsMessage,
        onError: (e) {
          if (kDebugMode) debugPrint('[WS] Error: $e');
          _handleWsDisconnect();
        },
        onDone: () {
          if (kDebugMode) debugPrint('[WS] Closed');
          _handleWsDisconnect();
        },
        cancelOnError: false,
      );
      _wsConnected = true;
      _setLink(LinkStatus.connected);
      if (kDebugMode) debugPrint('[WS] Connected');
    } catch (e) {
      _setLink(LinkStatus.error, 'WebSocket failed: $e');
      _scheduleReconnect();
    }
  }

  void _onWsMessage(dynamic message) {
    try {
      final text =
          message is String ? message : utf8.decode(message as List<int>);
      final jsonData = jsonDecode(text);
      if (jsonData is! Map<String, dynamic>) return;
      final model = Model.fromJson(jsonData);
      _latestData = model;
      _dataController?.add(model);
    } catch (e) {
      if (kDebugMode) debugPrint('[WS] Parse error: $e');
    }
  }

  void _handleWsDisconnect() {
    _wsConnected = false;
    _wsSub?.cancel();
    _wsSub = null;
    _channel = null;
    if (ConnectionConfig.hasSelection && ConnectionConfig.usesWebSocket) {
      _setLink(LinkStatus.disconnected);
      _scheduleReconnect();
    }
  }

  void _disconnectWebSocket() {
    _reconnectTimer?.cancel();
    _wsSub?.cancel();
    _wsSub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _wsConnected = false;
    _activeWsUrl = null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BLE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Auto-scan and connect (used after pairing or reconnect).
  Future<void> startBleScan() async {
    if (!_linkPaired) return;
    if (bleStatus == BleStatus.scanning || bleStatus == BleStatus.connecting) {
      return;
    }
    _reconnectTimer?.cancel();

    // Web Bluetooth cannot silently re-scan (that needs a user gesture), but it
    // can reconnect to an already-granted device's GATT server directly.
    if (kIsWeb) {
      final device = _device;
      if (device != null) {
        await _connectBle(device);
      }
      return;
    }

    await _stopBleScan();

    _setBle(BleStatus.scanning);
    _setLink(LinkStatus.connecting);
    if (kDebugMode) debugPrint('[BLE] Scanning for "CanSat-GS"…');

    try {
      var found = false;
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        if (found || results.isEmpty) return;
        found = true;
        if (kDebugMode) {
          debugPrint('[BLE] Found ${results.first.device.platformName}');
        }
        _stopBleScan().then((_) => _connectBle(results.first.device));
      });

      await FlutterBluePlus.startScan(
        withNames: ['CanSat-GS'],
        timeout: const Duration(seconds: 10),
      );

      if (!found && bleStatus == BleStatus.scanning) {
        _setBle(BleStatus.disconnected);
        _setLink(LinkStatus.disconnected);
        _scheduleReconnect();
      }
    } catch (e) {
      _setBle(BleStatus.error, e.toString());
      _setLink(LinkStatus.error, e.toString());
      _scheduleReconnect();
    }
  }

  Future<void> _stopBleScan() async {
    await _scanSub?.cancel();
    _scanSub = null;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  Future<void> _connectBle(BluetoothDevice device) async {
    _setBle(BleStatus.connecting);
    _device = device;

    try {
      await _bleConnectDevice(device);
      _listenBleConnection(device);

      await _bleRequestMtu(device);
      await _bleGattPause();

      final services = await _discoverBleServices(device);
      _resolveBleCharacteristics(services);
      if (_txChar == null) {
        throw Exception('Telemetry TX characteristic not found');
      }

      await _txChar!.setNotifyValue(true);
      await _bleGattPause(const Duration(milliseconds: 300));

      await _listenTelemetryNotify(device);

      if (_linkPaired && _blePairDigits != null && _rxChar != null) {
        await _writePairCode(_blePairDigits!);
        if (kDebugMode) {
          debugPrint('[BLE] Re-sent PAIR after reconnect');
        }
      }

      await _subscribeBleCamera(device);

      connectedDeviceName = device.platformName;
      _setBle(BleStatus.connected);
      _setLink(LinkStatus.connected);
    } catch (e) {
      _setBle(BleStatus.error, e.toString());
      _setLink(LinkStatus.error, e.toString());
      _handleBleDisconnect();
    }
  }

  /// Enable camera notifications (call after pairing or when opening camera tab).
  Future<void> ensureBleCameraListening() async {
    if (!ConnectionConfig.usesBle) return;
    final device = _device;
    if (device == null || bleStatus != BleStatus.connected) return;
    if (_camChar != null &&
        _camChar!.isNotifying &&
        _camNotifySub != null &&
        (!_bleUseWinrtDesktop || _camPlatformSub != null)) {
      return;
    }
    await _subscribeBleCamera(device);
  }

  /// Kept as compatibility no-op for existing UI calls.
  Future<void> enterWinrtCameraMode() async {
    await ensureBleCameraListening();
  }

  Future<void> exitWinrtCameraMode() async {
    // no-op
  }

  Future<void> _stopCamListeners() async {
    await _camNotifySub?.cancel();
    _camNotifySub = null;
    await _camPlatformSub?.cancel();
    _camPlatformSub = null;
    _camReadPollTimer?.cancel();
    _camReadPollTimer = null;
    _camReadInFlight = false;
  }

  Future<void> _subscribeBleCamera(BluetoothDevice device) async {
    try {
      await _stopCamListeners();

      if (_camChar == null) {
        final services = await _discoverBleServices(device);
        _resolveBleCharacteristics(services);
      }
      if (_camChar == null) {
        if (kDebugMode) {
          debugPrint(
            '[BLE] No camera service on GS — camera disabled in firmware',
          );
        }
        return;
      }

      // Listen before setNotifyValue so WinRT does not drop early packets.
      _camNotifySub = _camChar!.onValueReceived.listen(_onCameraChunk);

      if (_bleUseWinrtDesktop) {
        final remoteIdStr = device.remoteId.str.toLowerCase();
        _camPlatformSub = FlutterBluePlusPlatform.instance.onCharacteristicReceived
            .where((p) => p.success)
            .listen((p) {
          final sameDevice = p.remoteId.str.toLowerCase() == remoteIdStr;
          final isCam = _bleUuidMatches(p.characteristicUuid.str, _kCamTx);
          if (sameDevice && isCam) {
            _onCameraChunk(p.value);
          }
        });
      }

      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          await _camChar!.setNotifyValue(true);
          await _bleGattPause(
            Duration(milliseconds: _bleUseWinrtDesktop ? 400 : 150),
          );
          if (_camChar!.isNotifying) break;
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[BLE] Camera setNotify attempt ${attempt + 1}: $e');
          }
        }
      }

      if (kDebugMode) {
        debugPrint(
          '[BLE] Camera subscribed (notifying=${_camChar!.isNotifying}, '
          'telemNotifying=${_txChar?.isNotifying}, winrt=${_bleUseWinrtDesktop})',
        );
      }

      // Aggressive GATT reads on Windows can starve notification delivery.
      // Disable read polling entirely; rely on notifications only.
    } catch (e) {
      if (kDebugMode) debugPrint('[BLE] Camera subscribe failed: $e');
    }
  }

  Future<void> _pollCamCharacteristicRead() async {
    final c = _camChar;
    if (c == null || _camReadInFlight) return;
    _camReadInFlight = true;
    _camReadAttempts++;
    try {
      final data = await c.read();
      if (data.isNotEmpty) {
        _onCameraChunk(data);
      }
    } catch (e) {
      if (kDebugMode && _bleCameraNotifyCount < 3) {
        debugPrint('[BLE] Camera read poll: $e');
      }
    } finally {
      _camReadInFlight = false;
    }
  }

  bool _isPairOnlyMessage(String text) {
    final t = text.trim();
    return t.startsWith('{"pair":') && t.endsWith('}') && t.length < 32;
  }

  void _handleBleNotify(
    List<int> bytes, {
    void Function()? onPairOk,
    void Function()? onPairFail,
  }) {
    final text = utf8.decode(bytes, allowMalformed: true);
    if (kDebugMode && (onPairOk != null || text.contains('"pair":'))) {
      final preview = text.length > 60 ? text.substring(0, 60) : text;
      debugPrint('[BLE notify] ${bytes.length}B: $preview');
    }
    if (text.contains('"pair":"ok"')) onPairOk?.call();
    if (text.contains('"pair":"fail"')) onPairFail?.call();
    if (!_isPairOnlyMessage(text)) {
      _onBleData(bytes);
    }
  }

  void _onBleData(List<int> bytes) {
    final chunk = utf8.decode(bytes, allowMalformed: true);

    _rxBuffer.write(chunk);

    final s = _rxBuffer.toString();
    final end = s.lastIndexOf('}');
    if (end == -1) return;

    final start = s.lastIndexOf('{', end);
    if (start == -1) {
      _rxBuffer.clear();
      return;
    }

    final jsonStr = s.substring(start, end + 1);
    _rxBuffer.clear();
    if (end + 1 < s.length) _rxBuffer.write(s.substring(end + 1));

    try {
      final jsonData = jsonDecode(jsonStr);
      if (jsonData is Map<String, dynamic>) {
        final model = Model.fromJson(jsonData);
        _latestData = model;
        _dataController?.add(model);
        if (kDebugMode) {
          debugPrint(
            '[BLE] Telemetry temp=${model.temperature} roll=${model.roll}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BLE] JSON parse error: $e | chunk: $jsonStr');
      }
    }
  }

  void _onCameraChunk(List<int> bytes) {
    if (bytes.isEmpty) return;

    // Platform + onValueReceived + read poll may deliver the same chunk twice.
    if (bytes.length >= 6) {
      final key = Object.hashAll(bytes.sublist(0, 6)) ^ bytes.length;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (key == _camDedupeKey && now - _camDedupeMs < 8) return;
      _camDedupeKey = key;
      _camDedupeMs = now;
    }

    _bleCameraNotifyCount++;
    _bleCameraLastNotifyBytes = bytes.length;

    // GS firmware (Android): each notify = 6-byte BE header + JPEG slice.
    _processCamNotifyLegacy(Uint8List.fromList(bytes));
  }

  void _processCamNotifyLegacy(Uint8List bytes) {
    if (bytes.length < 7) return;

    final frameId = ((bytes[0] & 0xFF) << 8) | (bytes[1] & 0xFF);
    final packetId = ((bytes[2] & 0xFF) << 8) | (bytes[3] & 0xFF);
    final totalPackets = ((bytes[4] & 0xFF) << 8) | (bytes[5] & 0xFF);
    final chunk = bytes.sublist(6);
    _addCamChunk(frameId, packetId, totalPackets, chunk);
  }

  void _addCamChunk(
    int frameId,
    int packetId,
    int totalPackets,
    List<int> chunk,
  ) {
    if (totalPackets == 0 || totalPackets > 512) {
      if (kDebugMode && _camChunksReceived < 5) {
        debugPrint(
          '[BLE] Camera skip: bad total=$totalPackets (len=${chunk.length})',
        );
      }
      return;
    }
    if (packetId >= totalPackets) return;

    _camChunksReceived++;

    if (packetId == 0 || frameId != _camCurrentFrame) {
      _camChunks.clear();
      _camCurrentFrame = frameId;
      _camExpectedChunks = totalPackets;
    }

    _camChunks[packetId] = Uint8List.fromList(chunk);

    if (_camChunks.length < _camExpectedChunks) return;

    for (var i = 0; i < _camExpectedChunks; i++) {
      if (!_camChunks.containsKey(i)) return;
    }

    final builder = BytesBuilder();
    for (var i = 0; i < _camExpectedChunks; i++) {
      builder.add(_camChunks[i]!);
    }
    final jpeg = builder.toBytes();
    _camChunks.clear();

    if (!_isCompleteJpeg(jpeg)) {
      if (kDebugMode) {
        debugPrint('[BLE] Camera frame bad JPEG (${jpeg.length} B)');
      }
      return;
    }

    _bleCameraFrameCount++;
    _cameraController?.add(jpeg);
    if (kDebugMode) {
      debugPrint(
        '[BLE] Camera JPEG ${jpeg.length} B (#$_bleCameraFrameCount)',
      );
    }
  }

  static bool _isCompleteJpeg(Uint8List bytes) {
    if (bytes.length < 80) return false;
    if (bytes[0] != 0xFF || bytes[1] != 0xD8) return false;
    var end = bytes.length;
    while (end > 2 && bytes[end - 1] == 0) {
      end--;
    }
    return end >= 2 && bytes[end - 2] == 0xFF && bytes[end - 1] == 0xD9;
  }

  void _handleBleDisconnect() {
    _notifySub?.cancel();
    _notifySub = null;
    _telemPlatformSub?.cancel();
    _telemPlatformSub = null;
    unawaited(_stopCamListeners());
    _connSub?.cancel();
    _connSub = null;
    _txChar = null;
    _rxChar = null;
    _camChar = null;
    _bleServices = null;
    _camChunks.clear();
    _camChunksReceived = 0;
    _camDedupeKey = -1;
    _camDedupeMs = 0;
    _bleCameraNotifyCount = 0;
    _bleCameraLastNotifyBytes = 0;
    connectedDeviceName = null;
    _linkPaired = false;
    _blePairDigits = null;
    _rxBuffer.clear();
    _setBle(BleStatus.disconnected);
    if (ConnectionConfig.hasSelection && ConnectionConfig.usesBle) {
      _setLink(LinkStatus.disconnected);
      _scheduleReconnect();
    }
  }

  Future<void> _disconnectBle() async {
    await _stopBleScan();
    _notifySub?.cancel();
    _telemPlatformSub?.cancel();
    _telemPlatformSub = null;
    await _stopCamListeners();
    _connSub?.cancel();
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
    _txChar = null;
    _rxChar = null;
    _camChar = null;
    _bleServices = null;
    _setBle(BleStatus.idle);
  }

  Future<void> sendCommand(String cmd) async {
    if (_rxChar == null || bleStatus != BleStatus.connected) return;
    try {
      await _rxChar!.write(utf8.encode(cmd));
    } catch (e) {
      if (kDebugMode) debugPrint('[BLE] Write error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Reconnect / dispose
  // ═══════════════════════════════════════════════════════════════════════════

  void _scheduleReconnect() {
    if (!ConnectionConfig.hasSelection) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (ConnectionConfig.usesBle && _linkPaired) {
        startBleScan();
      } else if (ConnectionConfig.usesWebSocket && _linkPaired) {
        connectWithSelectedMode();
      }
    });
  }

  void _setBle(BleStatus s, [String? error]) {
    bleStatus = s;
    if (error != null) linkError = error;
  }

  void _setLink(LinkStatus s, [String? error]) {
    linkStatus = s;
    linkError = error;
  }

  /// Tear down links before returning to connection mode selection.
  Future<void> disconnectForModeChange() async {
    _reconnectTimer?.cancel();
    _linkPaired = false;
    connectedDeviceName = null;
    linkError = null;
    _stopSimulation();
    await stopBleDiscovery();
    await _disconnectBle();
    _disconnectWebSocket();
    _setBle(BleStatus.idle);
    _setLink(LinkStatus.idle);
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _stopSimulation();
    _disconnectWebSocket();
    _disconnectBle();
    _dataController?.close();
    _cameraController?.close();
  }

  static Future<Model> fetchWorldStates(String type) async {
    final vm = ViewModel();
    if (vm._latestData != null) return vm._latestData!;
    return vm.dataStream.first.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Timeout waiting for telemetry'),
    );
  }
}
