import 'package:flutter/material.dart';
import 'package:src/main.dart';
import 'package:src/theme/app_theme_colors.dart';

/// Light/dark switch for the side menu.
///
/// The switch reflects the brightness that is actually painted — so while the
/// app is still following the system it shows the system's choice, and the
/// first tap pins the opposite mode. Long-press hands control back to the
/// system setting.
class ThemeWidget extends StatelessWidget {
  const ThemeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = colors.isDark;

    final textStyle = TextStyle(
      fontSize: 16,
      color: colors.textPrimary,
      fontWeight: FontWeight.normal,
      letterSpacing: 0.0,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 13, bottom: 13, left: 12),
      child: Tooltip(
        message: themeManager.followsSystem
            ? 'Following the system theme — tap to pin light or dark'
            : 'Long-press to follow the system theme again',
        child: GestureDetector(
          onLongPress: themeManager.useSystemTheme,
          child: SwitchListTile.adaptive(
            value: isDark,
            onChanged: themeManager.toggleTheme,
            title: Text(
              isDark ? 'Dark Theme' : 'Light Theme',
              style: textStyle,
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
            subtitle: themeManager.followsSystem
                ? Text(
                    'System',
                    style: TextStyle(fontSize: 11, color: colors.textTertiary),
                  )
                : null,
            secondary: Icon(
              isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round_sharp,
              color: isDark ? colors.info : colors.warning,
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}
