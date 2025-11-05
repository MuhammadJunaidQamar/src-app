import 'dart:async';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:src/model/model.dart';
import 'package:src/view_model/view_model.dart';

class LiveGeoLocationOnMobileWidget extends StatefulWidget {
  const LiveGeoLocationOnMobileWidget({super.key});

  @override
  State<StatefulWidget> createState() => LiveGeoLocationOnMobileWidgetState();
}

class LiveGeoLocationOnMobileWidgetState
    extends State<LiveGeoLocationOnMobileWidget> {
  mb.MapboxMap? mapboxMap;
  Model model = Model();
  StreamSubscription<Model>? _dataSubscription;
  bool _isLoading = false;
  double latitude = 31.4469;
  double longitude = 74.2682;

  mb.PointAnnotationManager? pointAnnotationManager;

  bool _isUserInteracting = false;

  @override
  void initState() {
    super.initState();
    _subscribeToData();
  }

  void _subscribeToData() {
    final viewModel = ViewModel();

    // Subscribe to real-time WebSocket stream
    _dataSubscription = viewModel.dataStream.listen(
      (fetchedModel) {
        if (mounted) {
          _updateCoordinates(fetchedModel);
          if (!_isUserInteracting) _easeToLocation();
        }
      },
      onError: (error) {
        _handleSnackBar(error, ContentType.failure, 'Error!');
      },
    );

    // Load initial data if available
    if (viewModel.latestData != null) {
      _updateCoordinates(viewModel.latestData!);
    }
  }

  void _handleSnackBar(Object error, ContentType contentType, String title) {
    if (kDebugMode) {
      print('Error: $title');
    }
    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      content: AwesomeSnackbarContent(
        title: title,
        message: error.toString(),
        contentType: contentType,
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(snackBar);
    }
  }

  void _updateCoordinates(Model fetchedModel) {
    if (mapboxMap == null) return;

    setState(() {
      model = fetchedModel;
      final coordinates = model.getProperty('GPS') ?? 0;
      if (coordinates != 0.0) {
        latitude += 0.001; // coordinates.latitude;
        longitude += 0.000001; // coordinates.longitude;
        _isLoading = false;

        if (kDebugMode) {
          print('Updated coordinates: Lat: $latitude, Lng: $longitude');
        }

        _updatePointAnnotation(mapboxMap!, longitude, latitude);
        if (!_isUserInteracting) _easeToLocation();
      }
    });
  }

  void _updatePointAnnotation(
      mb.MapboxMap mapboxMap, double longitude, double latitude) async {
    if (pointAnnotationManager == null) return;

    final ByteData bytes = await rootBundle.load('assets/icons/satellite.png');
    final Uint8List imageData = bytes.buffer.asUint8List();

    mb.PointAnnotationOptions pointAnnotationOptions =
        mb.PointAnnotationOptions(
      geometry: mb.Point(coordinates: mb.Position(longitude, latitude)),
      image: imageData,
      iconSize: 0.2,
    );

    await pointAnnotationManager!.deleteAll();
    await pointAnnotationManager!.create(pointAnnotationOptions);
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    mb.MapOptions mapOptions = mb.MapOptions(
      pixelRatio: 1.0,
    );

    return _isLoading
        ? Center(
            child: CircularProgressIndicator.adaptive(),
          )
        : Stack(
            children: [
              mb.MapWidget(
                key: ValueKey("mapWidget"), //
                mapOptions: mapOptions, //
                onMapCreated: (mb.MapboxMap map) {
                  mapboxMap = map;
                  _onMapCreated(mapboxMap!);
                },
                styleUri:
                    "mapbox://styles/university-of-central-punjab/cm1v3ghd9016b01pe3gmwb9g4",
                onTapListener: _onTap,
                onScrollListener: _onMapInteraction,
                onLongTapListener: _onMapInteraction,
              ),
              Positioned(
                bottom: 20,
                right: 20,
                child: FloatingActionButton(
                  onPressed: _resetCameraFollow,
                  child: Icon(Icons.my_location),
                ),
              ),
            ],
          );
  }

  void _flyToLocation() {
    if (mapboxMap == null) return;

    mapboxMap!.flyTo(
      mb.CameraOptions(
        center: mb.Point(coordinates: mb.Position(longitude, latitude)),
        zoom: 17,
        bearing: 180,
        pitch: 30,
      ),
      mb.MapAnimationOptions(duration: 4000, startDelay: 1000),
    );
  }

  void _easeToLocation() {
    if (mapboxMap == null) return;

    mapboxMap!.easeTo(
      mb.CameraOptions(
        center: mb.Point(coordinates: mb.Position(longitude, latitude)),
        zoom: 17,
        bearing: 180,
        pitch: 30,
      ),
      mb.MapAnimationOptions(duration: 2000, startDelay: 0),
    );
  }

  Future<void> _onMapCreated(mb.MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    pointAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();
    _updatePointAnnotation(mapboxMap, longitude, latitude);
    if (!_isUserInteracting) _flyToLocation();
  }

  void _onTap(mb.MapContentGestureContext context) {
    _handleSnackBar(
        "Lng {${context.point.coordinates.lng},\nLat ${context.point.coordinates.lat}}",
        ContentType.help,
        "Coordinates");
    if (kDebugMode) {
      print(
          "OnTap coordinate: {${context.point.coordinates.lng}, ${context.point.coordinates.lat}}\npoint: {x: ${context.touchPosition.x}, y: ${context.touchPosition.y}}");
    }
  }

  void _onMapInteraction(mb.MapContentGestureContext context) {
    setState(() {
      _isUserInteracting = true;
    });
  }

  void _resetCameraFollow() {
    setState(() {
      _isUserInteracting = false;
    });
    _flyToLocation();
  }
}
