import 'package:flutter/material.dart';

class LiveCameraFeedWidget extends StatelessWidget {
  const LiveCameraFeedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    var w = MediaQuery.of(context).size.width;

    return Center(child: Text('Live Camera Feed$w'));
  }
}
