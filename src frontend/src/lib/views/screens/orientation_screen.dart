import 'package:flutter/material.dart';
import 'package:src/widgets/custom_card_widget.dart';
import 'package:src/widgets/header_widget.dart';
import 'package:src/widgets/spatial_object_widget.dart';

class OrientationScreen extends StatelessWidget {
  const OrientationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return OrientationLayout();
  }
}

class OrientationLayout extends StatelessWidget {
  const OrientationLayout({super.key});

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
                    child: SpatialObjectWidget(),
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
