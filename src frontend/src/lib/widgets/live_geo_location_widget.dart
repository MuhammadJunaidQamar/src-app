import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

class LiveGeoLocationOnMobileWidget extends StatelessWidget {
  const LiveGeoLocationOnMobileWidget({super.key});

  @override
  Widget build(BuildContext context) {
    mb.CameraOptions camera = mb.CameraOptions(
      center: mb.Point(coordinates: mb.Position(-98.0, 39.5)),
      zoom: 2,
      bearing: 0,
      pitch: 0,
    );
    return mb.MapWidget(
      cameraOptions: camera,
    );
  }
}
