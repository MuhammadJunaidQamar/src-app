import 'package:flutter/material.dart';
import 'package:mjpeg_stream/mjpeg_stream.dart';
import 'package:src/utils/constants/constants.dart';

class LiveCameraFeedWidget extends StatelessWidget {
  const LiveCameraFeedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    var w = MediaQuery.of(context).size.width;

    return Center(
      child: MJPEGStreamScreen(
        width: w,
        height: w * 9 / 16,
        streamUrl: Constants.cameraStreamUrl,
        showLiveIcon: true,
        watermarkText: 'UCP',
      ),
    );
  }
}
