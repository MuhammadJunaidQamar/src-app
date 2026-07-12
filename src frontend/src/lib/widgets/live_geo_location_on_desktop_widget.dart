import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:src/utils/webview_environment.dart';
import 'package:src/model/model.dart';
import 'package:src/utils/constants/constants.dart';
import 'package:src/utils/desktop_interaction.dart';
import 'package:src/utils/mapbox_init.dart';
import 'package:src/utils/mapbox_map_config.dart';
import 'package:src/view_model/view_model.dart';
import 'package:src/widgets/map_missing_token_placeholder.dart';
import 'package:src/widgets/map_recenter_button.dart';
import 'package:src/widgets/map_satellite_hud.dart';

class LiveGeoLocationOnDesktopWidget extends StatefulWidget {
  const LiveGeoLocationOnDesktopWidget({super.key});

  @override
  State<LiveGeoLocationOnDesktopWidget> createState() =>
      LiveGeoLocationOnDesktopWidgetState();
}

class LiveGeoLocationOnDesktopWidgetState
    extends State<LiveGeoLocationOnDesktopWidget> {
  InAppWebViewController? _webController;
  StreamSubscription<Model>? _dataSubscription;
  bool _mapReady = false;
  bool _isLoading = true;
  String? _mapError;
  bool _isUserInteracting = false;

  double latitude = MapboxMapConfig.defaultLatitude;
  double longitude = MapboxMapConfig.defaultLongitude;

  late final String _mapUrl = _buildMapUrl();

  String _buildMapUrl() {
    // Desktop serves assets via InAppLocalhostServer on :8080. On web, resolve
    // against the app origin so the iframe loads the bundled HTML asset.
    final htmlUrl = kIsWeb
        ? Uri.base.resolve('assets/assets/webview/mapbox_map.html').toString()
        : 'http://localhost:8080/webview/mapbox_map.html';
    final iconUrl = kIsWeb
        ? Uri.base.resolve('assets/assets/icons/satellite.png').toString()
        : MapboxMapConfig.satelliteIconUrl;

    final query = {
      'token': mapboxAccessToken,
      'style': MapboxMapConfig.styleUri,
      'icon': iconUrl,
      'lng': longitude.toString(),
      'lat': latitude.toString(),
      'lightPreset': MapboxMapConfig.basemapLightPreset,
      'theme': MapboxMapConfig.basemapTheme,
      'show3dObjects': MapboxMapConfig.basemapShow3dObjects ? '1' : '0',
      // Cache-buster: WebView2 otherwise keeps serving the old HTML asset.
      'v': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    final qs = query.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$htmlUrl?$qs';
  }

  @override
  void initState() {
    super.initState();
    _subscribeToData();
  }

  void _subscribeToData() {
    final viewModel = ViewModel();

    _dataSubscription = viewModel.dataStream.listen(
      (fetchedModel) {
        if (mounted) {
          _updateCoordinates(fetchedModel);
        }
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint('Geo map telemetry stream error: $error');
        }
      },
    );

    if (viewModel.latestData != null) {
      _updateCoordinates(viewModel.latestData!);
    }
  }

  void _updateCoordinates(Model fetchedModel) {
    final gps = fetchedModel.gps;
    if (gps == null || (gps.latitude == 0 && gps.longitude == 0)) {
      return;
    }

    setState(() {
      latitude = gps.latitude;
      longitude = gps.longitude;
    });

    if (kDebugMode) {
      print('Updated coordinates: Lat: $latitude, Lng: $longitude');
    }

    _pushPositionToMap(animate: true);
  }

  void _syncMapToCurrentPosition({required bool animate}) {
    if (!_mapReady || _webController == null) return;
    unawaited(_pushPositionToMap(animate: animate));
  }

  Future<void> _pushPositionToMap({required bool animate}) async {
    if (!_mapReady || _webController == null) return;

    final allowFollow = !_isUserInteracting;
    await _webController!.evaluateJavascript(source: '''
      window.mapBridge.updatePosition($longitude, $latitude, ${animate ? 'true' : 'false'}, ${allowFollow ? 'true' : 'false'});
    ''');
  }

  /// flutter_inappwebview's JS callHandler bridge is not available on web, so
  /// we poll the Mapbox instance after the HTML loads instead of waiting for
  /// mapLoaded from JavaScript.
  Future<void> _waitForMapReady(InAppWebViewController controller) async {
    const pollInterval = Duration(milliseconds: 250);
    const maxAttempts = 120; // ~30s

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (!mounted || _mapReady) return;

      final result = await controller.evaluateJavascript(source: '''
        (function() {
          if (typeof map !== 'undefined' && map && map.loaded && map.loaded()) {
            return 'ready';
          }
          var loading = document.getElementById('loading');
          if (loading && loading.style.display === 'none') return 'ready';
          return '';
        })();
      ''');

      if (_isMapReadyPollResult(result)) {
        if (!mounted || _mapReady) return;
        setState(() {
          _mapReady = true;
          _isLoading = false;
          _mapError = null;
        });
        _syncMapToCurrentPosition(animate: false);
        return;
      }

      await Future<void>.delayed(pollInterval);
    }

    if (!mounted || _mapReady) return;
    setState(() {
      _mapError = kIsWeb
          ? 'Map took too long to load. Check your network and Mapbox token.'
          : 'Map took too long to load.';
      _isLoading = false;
    });
  }

  bool _isMapReadyPollResult(dynamic result) {
    if (result == null) return false;
    final normalized = result.toString().replaceAll('"', '').trim();
    return normalized == 'ready';
  }

  void _resetCameraFollow() {
    setState(() => _isUserInteracting = false);
    _webController?.evaluateJavascript(
      source: 'window.mapBridge.recenter();',
    );
  }

  void _beginUserInteraction() {
    if (_isUserInteracting) return;
    _isUserInteracting = true;
    _webController?.evaluateJavascript(
      source: 'window.mapBridge.setUserInteracting(true);',
    );
  }

  Future<void> _forwardWheelToMap(PointerScrollEvent event) async {
    if (!_mapReady || _webController == null) return;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    await _webController!.evaluateJavascript(
      source:
          'window.mapBridge.wheelZoom(${event.scrollDelta.dy}, ${ctrl ? 'true' : 'false'});',
    );
  }

  Future<void> _zoomBy(double delta) async {
    if (!_mapReady || _webController == null) return;
    await _webController!.evaluateJavascript(
      source: 'window.mapBridge.zoomBy($delta);',
    );
  }

  // Windows precision trackpads report two-finger gestures as pan-zoom
  // pointer events (not scroll events), which never reach the WebView.
  double _panZoomLastScale = 1.0;
  int? _dragPointer;
  Offset? _lastDragPosition;

  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons != kPrimaryMouseButton) return;
    _dragPointer = event.pointer;
    _lastDragPosition = event.position;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_dragPointer != event.pointer || _lastDragPosition == null) return;

    final delta = event.position - _lastDragPosition!;
    _lastDragPosition = event.position;
    if (delta.dx.abs() < 0.5 && delta.dy.abs() < 0.5) return;

    _beginUserInteraction();
    _webController?.evaluateJavascript(
      source: 'window.mapBridge.panBy(${delta.dx}, ${delta.dy});',
    );
  }

  void _onPointerUp(PointerUpEvent event) {
    _endPointerDrag(event.pointer);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _endPointerDrag(event.pointer);
  }

  void _endPointerDrag(int pointer) {
    if (_dragPointer != pointer) return;
    _dragPointer = null;
    _lastDragPosition = null;
  }

  void _onPanZoomStart(PointerPanZoomStartEvent event) {
    _panZoomLastScale = 1.0;
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (!_mapReady || _webController == null) return;

    final dx = event.panDelta.dx;
    final dy = event.panDelta.dy;
    if (dx.abs() > 0.01 || dy.abs() > 0.01) {
      _beginUserInteraction();
      _webController!.evaluateJavascript(
        source: 'window.mapBridge.panBy($dx, $dy);',
      );
    }

    if (event.scale > 0 && _panZoomLastScale > 0) {
      final zoomDelta = (math.log(event.scale / _panZoomLastScale)) / math.ln2;
      if (zoomDelta.abs() > 0.001) {
        _webController!.evaluateJavascript(
          source: 'window.mapBridge.pinchZoom($zoomDelta);',
        );
      }
    }
    _panZoomLastScale = event.scale;
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!mapboxSdkConfigured) {
      return const MapMissingTokenPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Focus(
            autofocus: true,
            child: InAppWebView(
              webViewEnvironment: webViewEnvironment,
              initialUrlRequest: URLRequest(url: WebUri(_mapUrl)),
              initialSettings: InAppWebViewSettings(
                transparentBackground: false,
                supportZoom: false,
                cacheEnabled: false,
                disableHorizontalScroll: false,
                disableVerticalScroll: false,
                horizontalScrollBarEnabled: false,
                verticalScrollBarEnabled: false,
                disableContextMenu: false,
                isInspectable: kDebugMode,
                underPageBackgroundColor: AppColors.eigengrauColor,
              ),
              onWebViewCreated: (controller) {
                _webController = controller;
                controller.addJavaScriptHandler(
                  handlerName: 'mapTap',
                  callback: (args) {
                    if (kDebugMode) {
                      double? lng;
                      double? lat;
                      if (args.length >= 2) {
                        lng = _asDouble(args[0]);
                        lat = _asDouble(args[1]);
                      } else if (args.isNotEmpty && args.first is Map) {
                        final map = args.first as Map;
                        lng = _asDouble(map['lng']);
                        lat = _asDouble(map['lat']);
                      }
                      if (lng != null && lat != null) {
                        debugPrint('Map tap: lng=$lng lat=$lat');
                      }
                    }
                  },
                );
                controller.addJavaScriptHandler(
                  handlerName: 'mapLoaded',
                  callback: (args) {
                    if (!mounted) return;
                    setState(() {
                      _mapReady = true;
                      _isLoading = false;
                      _mapError = null;
                    });
                    _syncMapToCurrentPosition(animate: false);
                  },
                );
                controller.addJavaScriptHandler(
                  handlerName: 'mapError',
                  callback: (args) {
                    if (!mounted) return;
                    final message = args.isNotEmpty
                        ? args.first.toString()
                        : 'Map failed to load';
                    setState(() {
                      _mapError = message;
                      _isLoading = false;
                      _mapReady = false;
                    });
                  },
                );
              },
              onConsoleMessage: (controller, message) {
                if (kDebugMode) {
                  debugPrint('[Map WebView] ${message.message}');
                }
              },
              onLoadStop: (controller, url) async {
                await Future<void>.delayed(const Duration(milliseconds: 200));
                await controller.evaluateJavascript(
                  source: 'window.mapBridge && window.mapBridge.resize();',
                );
                // Always poll as a fallback; on web this is the only way to
                // detect readiness because callHandler is unsupported.
                unawaited(_waitForMapReady(controller));
              },
              onReceivedError: (controller, request, error) {
                if (!mounted) return;
                setState(() {
                  _mapError = error.description;
                  _isLoading = false;
                });
              },
            ),
          ),
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              onPointerSignal: (signal) {
                if (signal is PointerScrollEvent) {
                  _forwardWheelToMap(signal);
                }
              },
              onPointerPanZoomStart: _onPanZoomStart,
              onPointerPanZoomUpdate: _onPanZoomUpdate,
            ),
          ),
          if (_isLoading)
            const ColoredBox(
              color: AppColors.eigengrauColor,
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          if (_mapError != null)
            ColoredBox(
              color: AppColors.eigengrauColor,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined,
                          size: 40, color: AppColors.mainTextColor2),
                      const SizedBox(height: 12),
                      Text(
                        _mapError!,
                        style: const TextStyle(color: AppColors.mainTextColor2),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            top: 12,
            left: 12,
            child: IgnorePointer(
              child: MapSatelliteHud(
                latitude: latitude,
                longitude: longitude,
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: MapRecenterButton(
              heroTag: 'geo_location_recenter_desktop',
              onPressed: _mapReady ? _resetCameraFollow : null,
            ),
          ),
          Positioned(
            bottom: 88,
            right: 20,
            child: Column(
              children: [
                _ZoomButton(
                  heroTag: 'map_zoom_in_desktop',
                  icon: Icons.add,
                  onPressed: _mapReady ? () => _zoomBy(1) : null,
                ),
                const SizedBox(height: 8),
                _ZoomButton(
                  heroTag: 'map_zoom_out_desktop',
                  icon: Icons.remove,
                  onPressed: _mapReady ? () => _zoomBy(-1) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.heroTag,
    required this.icon,
    required this.onPressed,
  });

  final String heroTag;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onPressed == null ? SystemMouseCursors.basic : clickCursor,
      child: FloatingActionButton.small(
        heroTag: heroTag,
        mouseCursor:
            onPressed == null ? SystemMouseCursors.basic : clickCursor,
        onPressed: onPressed,
        child: Icon(icon),
      ),
    );
  }
}
