import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mjpeg_stream/mjpeg_stream.dart';
import 'package:src/theme/app_theme_colors.dart';
import 'package:src/utils/connection/connection_config.dart';
import 'package:src/utils/constants/constants.dart';
import 'package:src/view_model/view_model.dart';

/// Camera feed: MJPEG over HTTP (Wi‑Fi / broadcast) or JPEG frames over BLE.
class LiveCameraFeedWidget extends StatefulWidget {
  const LiveCameraFeedWidget({super.key});

  @override
  State<LiveCameraFeedWidget> createState() => _LiveCameraFeedWidgetState();
}

class _LiveCameraFeedWidgetState extends State<LiveCameraFeedWidget> {
  /// Letterbox / pillar-box fill behind a live video frame. Camera output is
  /// dark content, so this stays a dark neutral in both themes; the overlays
  /// drawn on top of it use the scrim/onScrim roles for the same reason.
  static const Color _feedLetterbox = Color(0xFF000000);

  final _vm = ViewModel();
  StreamSubscription<Uint8List>? _bleSub;
  Timer? _statsRefreshTimer;
  Timer? _camRetryTimer;
  ui.Image? _decodedImage;
  int _frameCount = 0;
  int _lastJpegBytes = 0;
  int _imageWidth = 0;
  int _imageHeight = 0;
  String? _statusHint;

  @override
  void initState() {
    super.initState();
    if (ConnectionConfig.usesBle) {
      _bleSub = _vm.cameraStream.listen(_onBleJpeg);
      _vm.ensureBleCameraListening();
      _statsRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _decodedImage == null) setState(() {});
      });
      _camRetryTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (!mounted || _decodedImage != null) return;
        unawaited(_vm.ensureBleCameraListening());
      });
    }
  }

  Future<void> _onBleJpeg(Uint8List jpeg) async {
    if (!mounted) return;
    if (!_isCompleteJpeg(jpeg)) return;

    ui.Image? decoded;
    try {
      final codec = await ui.instantiateImageCodec(jpeg);
      final frame = await codec.getNextFrame();
      decoded = frame.image;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BLE] JPEG decode failed: $e (${jpeg.length} B)');
      }
      return;
    }

    final old = _decodedImage;
    if (!mounted) {
      decoded.dispose();
      return;
    }

    setState(() {
      _decodedImage = decoded;
      _lastJpegBytes = jpeg.length;
      _imageWidth = decoded!.width;
      _imageHeight = decoded.height;
      _frameCount++;
      if (jpeg.length < 2000) {
        _statusHint =
            'Small frame (${jpeg.length} B, ${decoded.width}×${decoded.height}) — '
            'use ESP32-CAM + GS_TEST_BLE_CAMERA=0 for real video';
      } else {
        _statusHint = null;
      }
    });
    old?.dispose();
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

  @override
  void dispose() {
    _bleSub?.cancel();
    _statsRefreshTimer?.cancel();
    _camRetryTimer?.cancel();
    _decodedImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ConnectionConfig.usesSimulation) {
      return _buildSimulationPlaceholder();
    }
    if (ConnectionConfig.usesBle) {
      return _buildBleCamera();
    }
    return _buildMjpegCamera(context);
  }

  Widget _buildSimulationPlaceholder() {
    final colors = context.colors;
    // No video here — this is a plain panel, so it follows the theme surface.
    return ColoredBox(
      color: colors.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.science_outlined,
              color: colors.warning.withValues(alpha: 0.7),
              size: 56,
            ),
            const SizedBox(height: 14),
            Text(
              'Camera not available in simulation mode.\n'
              'Telemetry and charts use demo data.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textTertiary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBleCamera() {
    final colors = context.colors;
    final image = _decodedImage;
    if (image == null) {
      final noCamService = !_vm.bleCameraAvailable;
      final notifies = _vm.bleCameraNotifyCount;
      final frames = _vm.bleCameraFrameCount;
      final lastN = _vm.bleCameraLastNotifyBytes;
      // No frame yet — this is a plain status panel, not a video surface.
      return ColoredBox(
        color: colors.surface,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off,
                color: colors.textTertiary,
                size: 56,
              ),
              const SizedBox(height: 14),
              Text(
                noCamService
                    ? 'No BLE camera on ground station.\n'
                        'Re-flash GROUND_STATION_BLE (Huge APP, camera ON)\n'
                        'then pair again.'
                    : 'Waiting for camera…\n'
                        'Same GS firmware as Android (no re-flash needed).\n'
                        'If telemetry works, check camera tab after pairing.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textTertiary, fontSize: 12),
              ),
              if (!noCamService) ...[
                const SizedBox(height: 10),
                Text(
                  'BLE: notify=${_vm.bleCameraNotifying} · packets $notifies · '
                  'reads ${_vm.camReadAttempts} · frames $frames · last $lastN B',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                ),
                if (notifies > 0 && frames == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Packets OK (${_vm.camChunksReceived} chunks) but no JPEG yet —\n'
                      'rebuild app (packet parser fix).',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.warning, fontSize: 11),
                    ),
                  ),
              ],
            ],
          ),
        ),
      );
    }

    // Upscale tiny test / QQVGA frames so they are visible on desktop.
    final minSide = math.min(_imageWidth, _imageHeight);
    final scale = minSide > 0 && minSide < 120
        ? math.min(480.0 / _imageWidth, 360.0 / _imageHeight)
        : 1.0;

    return ColoredBox(
      color: _feedLetterbox,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Transform.scale(
              scale: scale,
              child: RawImage(
                image: image,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          if (_statusHint != null)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Text(
                _statusHint!,
                textAlign: TextAlign.center,
                // Sits on the dark video surface; warning reads on it in both
                // themes.
                style: TextStyle(color: colors.warning, fontSize: 11),
              ),
            ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors.scrim,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'BLE · #$_frameCount · ${_lastJpegBytes} B · '
                '${_imageWidth}×$_imageHeight',
                style: TextStyle(color: colors.onScrim, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMjpegCamera(BuildContext context) {
    final url = Constants.cameraStreamUrl;
    final w = MediaQuery.of(context).size.width;

    if (url.isEmpty) {
      return Center(
        child: Text(
          'No camera URL for this connection mode.',
          style: TextStyle(color: context.colors.textTertiary),
        ),
      );
    }

    return Center(
      child: MJPEGStreamScreen(
        width: w,
        height: w * 9 / 16,
        streamUrl: url,
        showLiveIcon: true,
        watermarkText: 'UCP',
      ),
    );
  }
}
