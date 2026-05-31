import 'dart:io';
import 'package:flutter/material.dart';
import 'package:src/widgets/live_geo_location_on_desktop_widget.dart';
import 'package:src/widgets/live_geo_location_on_mobile_widget.dart';

class GeoLocationOnlyWidget extends StatelessWidget {
  const GeoLocationOnlyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Row(
        children: [
          Expanded(
            flex: 75,
            child: Column(
              children: [
                Expanded(
                  child: Platform.isAndroid || Platform.isIOS
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
