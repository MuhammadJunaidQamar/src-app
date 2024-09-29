import 'package:flutter/material.dart';
import 'package:src/utils/responsive.dart';
import 'package:src/widgets/header_widget.dart';
import 'package:src/widgets/info_widget.dart';
import 'package:src/widgets/live_camera_feed_widget.dart';

class DashboardWidget extends StatelessWidget {
  const DashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18.0),
      child: Row(
        children: [
          Expanded(
            flex: 75,
            child: Column(
              children: [
                const HeaderWidget(),
                SizedBox(height: 18),
                Expanded(
                  child: !Responsive.isTablet(context)
                      ? LiveCameraFeedWidget()
                      : const SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: Column(
                            children: [
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: LiveCameraFeedWidget(),
                              ),
                              InfoWidget(),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          if (Responsive.isDesktop(context))
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
