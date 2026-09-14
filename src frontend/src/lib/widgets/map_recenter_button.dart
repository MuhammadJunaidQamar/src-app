import 'package:flutter/material.dart';
import 'package:src/theme/app_theme_colors.dart';
import 'package:src/utils/desktop_interaction.dart';

class MapRecenterButton extends StatelessWidget {
  const MapRecenterButton({
    super.key,
    required this.heroTag,
    required this.onPressed,
  });

  final String heroTag;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cursor =
        onPressed == null ? SystemMouseCursors.basic : clickCursor;
    return MouseRegion(
      cursor: cursor,
      child: FloatingActionButton(
        heroTag: heroTag,
        tooltip: 'Recenter on satellite',
        mouseCursor: cursor,
        // The button floats over the basemap, so pin it to a readable surface
        // instead of inheriting the default primary-container tint.
        backgroundColor: colors.surfaceElevated,
        foregroundColor: colors.textPrimary,
        onPressed: onPressed,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
