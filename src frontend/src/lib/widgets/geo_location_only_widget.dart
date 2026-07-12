import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:src/widgets/live_geo_location_on_desktop_widget.dart';
import 'package:src/widgets/live_geo_location_on_mobile_widget.dart';

class GeoLocationOnlyWidget extends StatelessWidget {
  const GeoLocationOnlyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // dart:io's Platform throws on web; use the web-safe platform check so the
    // native Mapbox widget is only chosen on real Android/iOS devices.
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Row(
        children: [
          Expanded(
            flex: 75,
            child: Column(
              children: [
                Expanded(
                  child: isMobile
                      ? LiveGeoLocationOnMobileWidget()
                      : LiveGeoLocationOnDesktopWidget(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
