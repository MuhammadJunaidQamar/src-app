import 'package:flutter/material.dart';
import 'package:src/utils/constants/constants.dart';

class MapMissingTokenPlaceholder extends StatelessWidget {
  const MapMissingTokenPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined,
                size: 48, color: AppColors.mainTextColor2),
            const SizedBox(height: 16),
            Text(
              'Map preview needs a Mapbox access token.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.mainTextColor1,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Add mapboxPublicToken in lib/utils/secrets/secrets.dart, '
              'or pass it at run time:',
              style: TextStyle(color: AppColors.mainTextColor2, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SelectableText(
              'flutter run --dart-define=ACCESS_TOKEN=pk....',
              style: TextStyle(
                color: AppColors.spanishSkyBlueColor,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
