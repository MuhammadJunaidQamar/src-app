import 'package:flutter/material.dart';
import 'package:src/utils/responsive.dart';
import 'package:src/widgets/custom_card_widget.dart';
import 'package:src/widgets/header_widget.dart';
import 'package:src/widgets/info_wiget.dart';
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
                      ? CustomCard(
                          child: LiveCameraFeedWidget(),
                        )
                      : const SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: Column(
                            children: [
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: CustomCard(
                                  child: LiveCameraFeedWidget(),
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
