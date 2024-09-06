import 'package:flutter/material.dart';
import 'package:src/utils/const/constants.dart';

class LiveCameraFeedWidget extends StatelessWidget {
  const LiveCameraFeedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    var w = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            width: 5,
            color: Theme.of(context).primaryColor,
          ),
          borderRadius: BorderRadius.all(
            Radius.circular(12.0),
          ),
          color: AppColors.cardBackgroundColor,
        ),
        child: Center(child: Text('Live Camera Feed$w')),
      ),
    );
  }
}
