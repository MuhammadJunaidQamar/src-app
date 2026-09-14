import 'package:flutter/material.dart';
import 'package:src/theme/app_theme_colors.dart';
import 'package:src/utils/desktop_interaction.dart';

/// Builds the single [ThemeData] shape the app uses, driven entirely by the
/// [AppThemeColors] palette handed in. Light and dark differ only in palette.
ThemeData buildAppTheme(AppThemeColors c) {
  final scheme = ColorScheme(
    brightness: c.brightness,
    primary: c.accent,
    onPrimary: c.onAccent,
    primaryContainer: c.surfaceMuted,
    onPrimaryContainer: c.textPrimary,
    secondary: c.info,
    onSecondary: c.isDark ? const Color(0xFF06212B) : Colors.white,
    secondaryContainer: c.surfaceMuted,
    onSecondaryContainer: c.textPrimary,
    tertiary: c.violet,
    onTertiary: Colors.white,
    error: c.danger,
    onError: Colors.white,
    errorContainer: c.danger.withValues(alpha: 0.16),
    onErrorContainer: c.textPrimary,
    surface: c.surface,
    onSurface: c.textPrimary,
    surfaceContainerLowest: c.background,
    surfaceContainerLow: c.surface,
    surfaceContainer: c.surfaceElevated,
    surfaceContainerHigh: c.surfaceMuted,
    surfaceContainerHighest: c.surfaceStrong,
    onSurfaceVariant: c.textSecondary,
    outline: c.border,
    outlineVariant: c.cardBorder,
    shadow: Colors.black,
    scrim: c.scrim,
    inverseSurface: c.isDark ? c.textPrimary : c.textStrong,
    onInverseSurface: c.background,
    inversePrimary: c.accent,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: c.brightness,
    colorScheme: scheme,
  );

  final textTheme = base.textTheme.apply(
    bodyColor: c.textPrimary,
    displayColor: c.textStrong,
    decorationColor: c.textSecondary,
  );

  return applyDesktopInteractionTheme(
    base.copyWith(
      extensions: <ThemeExtension<dynamic>>[c],
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      dividerColor: c.cardBorder,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: IconThemeData(color: c.textSecondary),
      primaryIconTheme: IconThemeData(color: c.textSecondary),
      dividerTheme: DividerThemeData(color: c.cardBorder, space: 1),
      drawerTheme: DrawerThemeData(
        backgroundColor: c.menuBackground,
        scrimColor: c.scrim,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: c.textStrong),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: c.textSecondary),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      listTileTheme: ListTileThemeData(
        textColor: c.textPrimary,
        iconColor: c.textSecondary,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.surfaceElevated,
          border: Border.all(color: c.cardBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(color: c.textPrimary, fontSize: 12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        circularTrackColor: c.surfaceMuted,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceElevated,
        contentTextStyle: TextStyle(color: c.textPrimary),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accent.withValues(alpha: 0.32),
        selectionHandleColor: c.accent,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          c.textTertiary.withValues(alpha: 0.55),
        ),
      ),
    ),
  );
}
