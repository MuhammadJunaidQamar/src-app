import 'package:flutter/material.dart';
import 'package:src/widgets/custom_card_widget.dart';
import 'package:src/widgets/header_widget.dart';
import 'package:src/widgets/live_geo_location_widget.dart';

class GeoLocationScreen extends StatelessWidget {
  const GeoLocationScreen({super.key});

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
                const HeaderWidget(),
                Expanded(
                  child: CustomCard(
                    child: LiveGeoLocationWidget(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
