import 'package:flutter/material.dart';
import 'package:src/utils/const/constants.dart';

class GeoLocationScreen extends StatelessWidget {
  const GeoLocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Expanded(
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
          child: Center(child: Text('Geo Location')),
        ),
      ),
    );
  }
}
