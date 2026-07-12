import 'dart:async';

import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:src/model/model.dart';
import 'package:src/utils/app_snackbar.dart';
import 'package:src/utils/constants/constants.dart';
import 'package:src/utils/map_position_smoother.dart';
import 'package:src/utils/mapbox_init.dart';
import 'package:src/utils/mapbox_map_config.dart';
import 'package:src/view_model/view_model.dart';
import 'package:src/widgets/map_missing_token_placeholder.dart';
import 'package:src/widgets/map_recenter_button.dart';
import 'package:src/widgets/map_satellite_hud.dart';

class LiveGeoLocationOnMobileWidget extends StatefulWidget {
  const LiveGeoLocationOnMobileWidget({super.key});

  @override
  State<LiveGeoLocationOnMobileWidget> createState() =>
      LiveGeoLocationOnMobileWidgetState();
}

class LiveGeoLocationOnMobileWidgetState
    extends State<LiveGeoLocationOnMobileWidget>
    with SingleTickerProviderStateMixin {
  mb.MapboxMap? mapboxMap;
  Model model = Model();
  StreamSubscription<Model>? _dataSubscription;
  bool _isLoading = false;

  /// Latest GPS sample (HUD / telemetry truth).
  double latitude = MapboxMapConfig.defaultLatitude;
  double longitude = MapboxMapConfig.defaultLongitude;

  late final MapPositionSmoother _smoother = MapPositionSmoother(
    initialLatitude: latitude,
    initialLongitude: longitude,
  );
  Ticker? _ticker;
  DateTime _lastMapSync = DateTime.fromMillisecondsSinceEpoch(0);
  static const _mapSyncInterval = Duration(milliseconds: 33); // ~30 fps
  /// While flyTo (load / recenter) is running, pause chase setCamera so the
  /// two don't fight and shake the map.
  bool _cameraAnimating = false;

  mb.PointAnnotationManager? pointAnnotationManager;
  mb.PointAnnotation? _satelliteAnnotation;
  Uint8List? _satelliteIconBytes;
  bool _annotationUpdateRunning = false;
  bool _annotationUpdatePending = false;
  bool _isUserInteracting = false;

  /// True while the user is mid-gesture (e.g. pinch). Pause camera follow so
  /// setCamera does not fight the gesture and flash tiles / the marker.
  bool _gestureInProgress = false;
  bool _ignoreCameraEvents = false;
  Timer? _cameraGuardTimer;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
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
        _showSnackBar(error.toString(), ContentType.failure, 'Error');
      },
    );

    if (viewModel.latestData != null) {
      _updateCoordinates(viewModel.latestData!);
    }
  }

  void _showSnackBar(String message, ContentType contentType, String title) {
    if (!mounted) return;
    showAppSnackBar(
      context,
      title: title,
      message: message,
      contentType: contentType,
    );
  }

  void _guardCameraEvents(Duration duration) {
    _cameraGuardTimer?.cancel();
    _ignoreCameraEvents = true;
    _cameraGuardTimer = Timer(duration, () {
      if (mounted) {
        _ignoreCameraEvents = false;
      }
    });
  }

  void _updateCoordinates(Model fetchedModel) {
    final gps = fetchedModel.gps;
    if (gps == null || (gps.latitude == 0 && gps.longitude == 0)) {
      return;
    }

    setState(() {
      model = fetchedModel;
      latitude = gps.latitude;
      longitude = gps.longitude;
      _isLoading = false;
    });

    if (kDebugMode) {
      print('Updated coordinates: Lat: $latitude, Lng: $longitude');
    }

    // Retarget the chase from wherever the display currently is — far jumps
    // just get a longer ease, never a hard snap.
    _smoother.setTarget(latitude, longitude);
  }

  void _onTick(Duration _) {
    if (_cameraAnimating) return;
    if (!_smoother.tick()) return;
    if (mapboxMap == null) return;
    final now = DateTime.now();
    if (now.difference(_lastMapSync) < _mapSyncInterval &&
        _smoother.isAnimating) {
      return;
    }
    _lastMapSync = now;
    unawaited(_syncDisplayToMap());
  }

  Future<void> _syncDisplayToMap() async {
    final lng = _smoother.displayLongitude;
    final lat = _smoother.displayLatitude;
    await _updatePointAnnotation(lng, lat);
    if (!_isUserInteracting && !_gestureInProgress) {
      await _followDisplay(lng, lat);
    }
  }

  Future<Uint8List> _loadSatelliteIcon() async {
    final cached = _satelliteIconBytes;
    if (cached != null) return cached;
    final ByteData bytes = await rootBundle.load('assets/icons/satellite.png');
    return _satelliteIconBytes = bytes.buffer.asUint8List();
  }

  Future<void> _updatePointAnnotation(
    double longitude,
    double latitude,
  ) async {
    if (_annotationUpdateRunning) {
      _annotationUpdatePending = true;
      return;
    }
    _annotationUpdateRunning = true;
    try {
      do {
        _annotationUpdatePending = false;
        await _applyPointAnnotation(
          _smoother.displayLongitude,
          _smoother.displayLatitude,
        );
      } while (_annotationUpdatePending);
    } finally {
      _annotationUpdateRunning = false;
    }
  }

  Future<void> _applyPointAnnotation(
    double longitude,
    double latitude,
  ) async {
    final manager = pointAnnotationManager;
    if (manager == null) return;

    final point = mb.Point(coordinates: mb.Position(longitude, latitude));
    final existing = _satelliteAnnotation;
    if (existing != null) {
      existing.geometry = point;
      await manager.update(existing);
      return;
    }

    final imageData = await _loadSatelliteIcon();
    // Another create may have finished while the icon was loading.
    if (_satelliteAnnotation != null) {
      _satelliteAnnotation!.geometry = point;
      await manager.update(_satelliteAnnotation!);
      return;
    }
    _satelliteAnnotation = await manager.create(
      mb.PointAnnotationOptions(
        geometry: point,
        image: imageData,
        iconSize: 0.2,
      ),
    );
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _dataSubscription?.cancel();
    _cameraGuardTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!mapboxSdkConfigured) {
      return const MapMissingTokenPlaceholder();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        mb.MapWidget(
          key: const ValueKey('mapWidget'),
          mapOptions: mb.MapOptions(pixelRatio: 1.0),
          onMapCreated: _onMapCreated,
          styleUri: MapboxMapConfig.styleUri,
          onTapListener: _onTap,
          // Pan stops follow; zoom pauses follow only for the gesture.
          onScrollListener: _onUserPan,
          onZoomListener: _onZoomGesture,
          onLongTapListener: _onUserPan,
          onMapIdleListener: _onMapIdle,
        ),
        if (_isLoading)
          const ColoredBox(
            color: AppColors.eigengrauColor,
            child: Center(child: CircularProgressIndicator.adaptive()),
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
            heroTag: 'geo_location_recenter',
            onPressed: _resetCameraFollow,
          ),
        ),
      ],
    );
  }

  mb.CameraOptions _defaultCameraOptions() {
    return mb.CameraOptions(
      center: mb.Point(
        coordinates: mb.Position(
          _smoother.displayLongitude,
          _smoother.displayLatitude,
        ),
      ),
      zoom: MapboxMapConfig.cameraZoom,
      bearing: MapboxMapConfig.cameraBearing,
      pitch: MapboxMapConfig.cameraPitch,
    );
  }

  void _flyToLocation() {
    if (mapboxMap == null) return;

    _cameraAnimating = true;
    _ignoreCameraEvents = true;
    _cameraGuardTimer?.cancel();
    mapboxMap!.flyTo(
      _defaultCameraOptions(),
      mb.MapAnimationOptions(
        duration: MapboxMapConfig.recenterFlyDurationMs,
        startDelay: 0,
      ),
    );
    // Resume chase after flyTo completes — don't let follow setCamera race it.
    _cameraGuardTimer = Timer(
      Duration(milliseconds: MapboxMapConfig.recenterFlyDurationMs + 150),
      () {
        if (!mounted) return;
        _ignoreCameraEvents = false;
        _cameraAnimating = false;
      },
    );
  }

  /// Lock camera center onto the smoothed display position. Marker and camera
  /// move together so the satellite never drifts off-screen while chasing.
  Future<void> _followDisplay(double longitude, double latitude) async {
    final map = mapboxMap;
    if (map == null ||
        _isUserInteracting ||
        _gestureInProgress ||
        _cameraAnimating) {
      return;
    }

    _guardCameraEvents(const Duration(milliseconds: 50));
    try {
      await map.setCamera(
        mb.CameraOptions(
          center: mb.Point(coordinates: mb.Position(longitude, latitude)),
        ),
      );
    } catch (_) {
      // Map may already be disposing between frames.
    }
  }

  Future<void> _onMapCreated(mb.MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    pointAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();

    final latest = ViewModel().latestData?.gps;
    if (latest != null && !(latest.latitude == 0 && latest.longitude == 0)) {
      latitude = latest.latitude;
      longitude = latest.longitude;
      _smoother.setTarget(latitude, longitude, snap: true);
    }

    await _updatePointAnnotation(
      _smoother.displayLongitude,
      _smoother.displayLatitude,
    );
    if (mounted) {
      setState(() => _isLoading = false);
    }
    if (!_isUserInteracting) {
      _flyToLocation();
    }
  }

  void _onTap(mb.MapContentGestureContext context) {
    final lng = context.point.coordinates.lng;
    final lat = context.point.coordinates.lat;
    _showSnackBar(
      'Lng: $lng\nLat: $lat',
      ContentType.help,
      'Coordinates',
    );
    if (kDebugMode) {
      print('OnTap coordinate: {$lng, $lat}');
    }
  }

  void _onUserPan(mb.MapContentGestureContext context) {
    if (_ignoreCameraEvents) return;
    _gestureInProgress = true;
    if (!_isUserInteracting) {
      setState(() => _isUserInteracting = true);
    }
  }

  void _onZoomGesture(mb.MapContentGestureContext context) {
    if (_ignoreCameraEvents) return;
    _gestureInProgress = true;
  }

  void _onMapIdle(mb.MapIdleEventData data) {
    if (!_gestureInProgress) return;
    _gestureInProgress = false;
    if (!_isUserInteracting) {
      unawaited(
        _followDisplay(
          _smoother.displayLongitude,
          _smoother.displayLatitude,
        ),
      );
    }
  }

  void _resetCameraFollow() {
    setState(() {
      _isUserInteracting = false;
      _gestureInProgress = false;
    });
    // Snap smoother to the live GPS target so recenter feels immediate.
    _smoother.setTarget(latitude, longitude, snap: true);
    unawaited(
      _updatePointAnnotation(
        _smoother.displayLongitude,
        _smoother.displayLatitude,
      ),
    );
    // Pause chase during flyTo — otherwise setCamera fights the animation
    // and the whole map shakes violently.
    _flyToLocation();
  }
}
