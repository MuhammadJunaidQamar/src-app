import 'package:flutter/material.dart';
import 'package:mjpeg_stream/mjpeg_stream.dart';

class LiveCameraFeedWidget extends StatelessWidget {
  const LiveCameraFeedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    var w = MediaQuery.of(context).size.width;

    return Center(
      child: MJPEGStreamScreen(
        width: w,
        height: w * 9 / 16,
        streamUrl: 'http://',
        showLiveIcon: true,
        watermarkText: 'UCP',
      ),
    );
  }
}
