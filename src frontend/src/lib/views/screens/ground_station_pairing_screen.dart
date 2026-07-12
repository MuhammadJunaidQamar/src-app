import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:src/model/model.dart';
import 'package:src/utils/connection/connection_config.dart';
import 'package:src/utils/constants/constants.dart';
import 'package:src/utils/routing/routes.dart';
import 'package:src/view_model/view_model.dart';
import 'package:src/widgets/custom_card_widget.dart';

/// Pick ground station (BLE list) and enter 6-digit code from Serial monitor.
class GroundStationPairingScreen extends StatefulWidget {
  const GroundStationPairingScreen({super.key});

  @override
  State<GroundStationPairingScreen> createState() =>
      _GroundStationPairingScreenState();
}

class _GroundStationPairingScreenState extends State<GroundStationPairingScreen> {
  final _vm = ViewModel();
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<Model>? _dataSub;

  List<ScanResult> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _scanning = false;
  bool _busy = false;
  String? _error;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    if (ConnectionConfig.selectedMode == ConnectionMode.broadcast ||
        ConnectionConfig.selectedMode == ConnectionMode.simulation) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _connectAuto());
    } else if (ConnectionConfig.usesBle && !kIsWeb) {
      // On web the browser device chooser must be opened from a user gesture,
      // so we wait for the user to tap "Scan" instead of auto-scanning.
      _startScan();
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _dataSub?.cancel();
    _codeController.dispose();
    _codeFocus.dispose();
    _vm.stopBleDiscovery();
    super.dispose();
  }

  Future<void> _connectAuto() async {
    setState(() => _busy = true);
    _vm.connectWithSelectedMode();
    _dataSub = _vm.dataStream.listen((_) => _goToApp());
    await Future.delayed(const Duration(milliseconds: 500));
    if (_vm.isConnected) _goToApp();
  }

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _error = null;
      _devices = [];
    });

    // permission_handler has no web backend; the browser handles Bluetooth
    // consent itself via the device chooser.
    if (!kIsWeb) {
      final blePermissions = <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ];
      final results = await blePermissions.request();
      final denied =
          results.entries.where((entry) => !entry.value.isGranted).toList();
      if (denied.isNotEmpty) {
        if (mounted) {
          setState(() {
            _scanning = false;
            _error =
                'Bluetooth/location permission is required to scan for CanSat-GS.';
          });
        }
        return;
      }
    }

    await _vm.stopBleDiscovery();
    _scanSub?.cancel();
    _scanSub = _vm.bleScanResults.listen((results) {
      // On web the browser chooser has already filtered to our GATT services,
      // so accept every returned device; on native, match by advertised name.
      final filtered = results.where((r) {
        if (kIsWeb) return true;
        return r.device.platformName.contains('CanSat');
      }).toList();
      filtered.sort((a, b) => b.rssi.compareTo(a.rssi));
      if (mounted) {
        setState(() {
          _devices = filtered;
          // The web chooser returns exactly the one device the user picked.
          if (kIsWeb && filtered.length == 1) {
            _selectedDevice = filtered.first.device;
          }
        });
      }
    });

    try {
      await _vm.startBleDiscovery();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = kIsWeb
              ? 'Web Bluetooth is unavailable or the picker was dismissed. '
                  'Use Chrome/Edge over HTTPS or localhost, then tap Scan.'
              : 'Bluetooth scan failed: $e';
        });
      }
    }
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _verifyAndConnect() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from Serial monitor.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (ConnectionConfig.usesBle) {
        final device = _selectedDevice;
        if (device == null) {
          setState(() {
            _error = 'Select your ground station from the list.';
            _busy = false;
          });
          return;
        }
        await _scanSub?.cancel();
        await _vm.stopBleDiscovery();
        final ok = await _vm.pairBleDevice(device, code);
        if (!ok) {
          setState(() {
            _error = kIsWeb
                ? 'Pairing failed. Check Serial for the latest 6-digit code, '
                    'enter it, tap Scan to pick the device again, then Verify.'
                : 'Pairing failed. Windows often drops BLE during setup — '
                    'check Serial for the latest 6-digit code, enter it, and retry. '
                    'If it keeps failing, remove "CanSat-GS" from Windows Bluetooth settings.';
            _busy = false;
          });
          return;
        }
        _dataSub = _vm.dataStream.listen((_) => _goToApp());
        _goToApp();
        return;
      }

      if (ConnectionConfig.selectedMode == ConnectionMode.directGroundStation) {
        final ok = await _vm.pairWifiWithCode(code);
        if (!ok) {
          setState(() {
            _error =
                'Wrong code or cannot reach 192.168.4.1. Join CanSat-GS Wi‑Fi first.';
            _busy = false;
          });
          return;
        }
        _vm.connectWithSelectedMode();
        _dataSub = _vm.dataStream.listen((_) => _goToApp());
        await Future.delayed(const Duration(milliseconds: 800));
        _goToApp();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  void _goToApp() {
    if (!mounted || _navigated) return;
    _navigated = true;
    _scanSub?.cancel();
    _vm.stopBleDiscovery();
    Routes.goToMainApp(context);
  }

  Future<void> _goBackToModeSelection() async {
    if (_busy) return;
    await _scanSub?.cancel();
    await _vm.stopBleDiscovery();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ConnectionConfig.selectedMode;
    if (mode == ConnectionMode.broadcast || mode == ConnectionMode.simulation) {
      return Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                mode == ConnectionMode.simulation
                    ? 'Starting simulation…'
                    : 'Connecting…',
                style: const TextStyle(color: AppColors.mainTextColor2),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.blackPearlColor,
        title: const Text('Verify ground station'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBackToModeSelection,
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : _goBackToModeSelection,
            child: const Text('Change method'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            CustomCard(
              color: AppColors.blackPearlColor.withValues(alpha: 0.85),
              padding: const EdgeInsets.all(18),
              margin: EdgeInsets.zero,
              expandChild: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pairing code',
                    style: TextStyle(
                      color: AppColors.contentColorWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ConnectionConfig.usesBle
                        ? '1. Open Serial Monitor on your ground station (115200 baud).\n'
                            '2. Note the 6-digit PAIRING CODE.\n'
                            '3. Select your station below, enter the code, tap Verify.'
                        : '1. Join Wi‑Fi "CanSat-GS" on this phone.\n'
                            '2. Note the 6-digit PAIRING CODE on Serial.\n'
                            '3. Enter the code and tap Verify.',
                    style: const TextStyle(
                      color: AppColors.mainTextColor2,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (ConnectionConfig.usesBle) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Nearby ground stations',
                    style: TextStyle(
                      color: AppColors.contentColorWhite,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _busy ? null : _startScan,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Scan'),
                  ),
                ],
              ),
              if (_scanning)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_devices.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    kIsWeb
                        ? 'Tap Scan to open the browser Bluetooth picker and '
                            'choose your CanSat-GS.'
                        : 'No CanSat-GS found. Power on the board and tap Scan.',
                    style: const TextStyle(color: AppColors.mainTextColor3),
                  ),
                )
              else
                ..._devices.map(_deviceTile),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              focusNode: _codeFocus,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                color: AppColors.contentColorWhite,
                fontSize: 28,
                letterSpacing: 8,
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                counterText: '',
                hintText: '000000',
                hintStyle: TextStyle(color: AppColors.mainTextColor3),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.spanishSkyBlueColor),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _busy ? null : _verifyAndConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mediumSeaGreenColor,
                  foregroundColor: Colors.white,
                ),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Verify & connect',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deviceTile(ScanResult r) {
    final device = r.device;
    final name = device.platformName.isEmpty ? 'Unknown' : device.platformName;
    final selected = _selectedDevice?.remoteId == device.remoteId;

    return Card(
      color: selected
          ? AppColors.blackPearlColor
          : AppColors.itemsBackground.withValues(alpha: 0.7),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          Icons.bluetooth,
          color: selected
              ? AppColors.tropicalIndigoColor
              : AppColors.mainTextColor2,
        ),
        title: Text(
          name,
          style: TextStyle(
            color: selected
                ? AppColors.contentColorWhite
                : AppColors.mainTextColor2,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          '${device.remoteId.str} · ${r.rssi} dBm',
          style: const TextStyle(
            color: AppColors.mainTextColor3,
            fontSize: 11,
          ),
        ),
        trailing: selected
            ? const Icon(Icons.check_circle, color: AppColors.mediumSeaGreenColor)
            : null,
        onTap: _busy
            ? null
            : () => setState(() => _selectedDevice = device),
      ),
    );
  }
}
