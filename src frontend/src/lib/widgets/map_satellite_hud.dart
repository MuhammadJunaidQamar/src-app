import 'package:flutter/material.dart';
import 'package:src/theme/app_theme_colors.dart';

/// Top-left overlay showing live satellite GPS coordinates.
class MapSatelliteHud extends StatelessWidget {
  const MapSatelliteHud({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          'Sat  ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
