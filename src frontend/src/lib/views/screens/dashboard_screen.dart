import 'package:flutter/material.dart';
import 'package:src/utils/responsive.dart';
import 'package:src/widgets/custom_card_widget.dart';
import 'package:src/widgets/geo_location_only_widget.dart';
import 'package:src/widgets/glob_only_widget.dart';
import 'package:src/widgets/header_widget.dart';
import 'package:src/widgets/info_widget.dart';
import 'package:src/widgets/live_camera_feed_widget.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);
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
                  child: !isTablet
                      ? Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CustomCard(
                              child: LiveCameraFeedWidget(),
                            ),
                            Positioned(
                              top: 20,
                              right: 50,
                              width: isDesktop ? 280 : 170,
                              height: isDesktop ? 220 : 130,
                              child: const GlobOnlyWidget(),
                            ),

                            // map widget
                            Positioned(
                              top: 12,
                              left: 50,
                              width: isDesktop ? 280 : 150,
                              height: isDesktop ? 220 : 130,
                              child: GeoLocationOnlyWidget(),
                            )
                          ],
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: Column(
                            children: [
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CustomCard(
                                      child: LiveCameraFeedWidget(),
                                    ),
                                    Positioned(
                                      top: 20,
                                      right: 50,
                                      width: isDesktop ? 280 : 170,
                                      height: isDesktop ? 220 : 130,
                                      child: GlobOnlyWidget(),
                                    ),
                                    // map widget
                                    Positioned(
                                      top: 12,
                                      left: 50,
                                      width: isDesktop ? 280 : 150,
                                      height: isDesktop ? 220 : 130,
                                      child: GeoLocationOnlyWidget(),
                                    )
                                  ],
                                ),
                              ),
                              InfoWidget(),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          if (isDesktop)
            Expanded(
              flex: 25,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: InfoWidget(),
              ),
            ),
        ],
      ),
    );
  }
}
