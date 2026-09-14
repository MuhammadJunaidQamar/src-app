import 'package:flutter/material.dart';

/// Semantic colour roles for the app, resolved per [Brightness].
///
/// Read it with `context.colors` (see [AppColorsContext]). Because it hangs off
/// [ThemeData.extensions], every widget that reads it becomes a dependent of
/// [Theme] and rebuilds automatically when the theme flips — which the old
/// `AppColors.*` static constants could never do.
@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.brightness,
    // Surfaces
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceMuted,
    required this.surfaceStrong,
    required this.menuBackground,
    required this.disabledSurface,
    // Lines
    required this.cardBorder,
    required this.border,
    required this.gridLine,
    required this.gridLineSubtle,
    // Text
    required this.textStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textMuted,
    // Accents
    required this.accent,
    required this.onAccent,
    required this.link,
    required this.positive,
    required this.warning,
    required this.danger,
    required this.info,
    required this.violet,
    // Overlays
    required this.scrim,
    required this.onScrim,
  });

  final Brightness brightness;

  /// Page / scaffold background.
  final Color background;

  /// Default card fill.
  final Color surface;

  /// Cards that need to sit above [surface] (side-menu cards, dialogs).
  final Color surfaceElevated;

  /// Tinted fill for list rows and unselected chips.
  final Color surfaceMuted;

  /// Strongest neutral fill — selected rows, chart plot areas.
  final Color surfaceStrong;

  /// Navigation rail / drawer background.
  final Color menuBackground;

  /// Fill for disabled buttons and inert icon tiles.
  final Color disabledSurface;

  /// 1px card outline.
  final Color cardBorder;

  /// General separator / outline.
  final Color border;

  final Color gridLine;
  final Color gridLineSubtle;

  /// Headline text — maximum contrast.
  final Color textStrong;

  /// Body text.
  final Color textPrimary;

  /// Supporting text.
  final Color textSecondary;

  /// Hints, captions, disabled labels.
  final Color textTertiary;

  /// De-emphasised metadata (title bar, footnotes).
  final Color textMuted;

  final Color accent;
  final Color onAccent;
  final Color link;
  final Color positive;
  final Color warning;
  final Color danger;
  final Color info;
  final Color violet;

  /// Translucent wash placed over content (error overlays, modal barriers).
  final Color scrim;

  /// Text/icons drawn on top of [scrim].
  final Color onScrim;

  bool get isDark => brightness == Brightness.dark;

  /// Brand accents are tuned for a dark canvas. On light surfaces they are too
  /// bright to carry white text or to read as a label, so darken them.
  Color tuneAccent(Color color) {
    if (isDark) return color;
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness * 0.66).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation * 1.05).clamp(0.0, 1.0))
        .toColor();
  }

  static const AppThemeColors dark = AppThemeColors(
    brightness: Brightness.dark,
    background: Color(0xFF10151D),
    surface: Color(0xFF10151D),
    surfaceElevated: Color(0xFF161F2C),
    surfaceMuted: Color(0xFF1B2339),
    surfaceStrong: Color(0xFF282E45),
    menuBackground: Color(0xFF090912),
    disabledSurface: Color(0xFF2E3C51),
    cardBorder: Color(0xFF2E3C51),
    border: Color(0x8AFFFFFF),
    gridLine: Color(0x1AFFFFFF),
    gridLineSubtle: Color(0x11FFFFFF),
    textStrong: Color(0xFFFFFFFF),
    textPrimary: Color(0xFFBFC7D2),
    textSecondary: Color(0xB3FFFFFF),
    textTertiary: Color(0x61FFFFFF),
    textMuted: Color(0xFF808C9C),
    accent: Color(0xFF2697FF),
    onAccent: Color(0xFFFFFFFF),
    link: Color(0xE125A6E9),
    positive: Color(0xFF17B877),
    warning: Color(0xFFFFA23E),
    danger: Color(0xFFE80054),
    info: Color(0xFF50E4FF),
    violet: Color(0xFFA87FFB),
    scrim: Color(0x8A000000),
    onScrim: Color(0xFFFFFFFF),
  );

  static const AppThemeColors light = AppThemeColors(
    brightness: Brightness.light,
    background: Color(0xFFEEF2F8),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFE6ECF5),
    surfaceStrong: Color(0xFFDCE4F0),
    menuBackground: Color(0xFFFFFFFF),
    disabledSurface: Color(0xFFC7D2E0),
    cardBorder: Color(0xFFD1DAE7),
    border: Color(0xFF97A4B8),
    gridLine: Color(0x1A000000),
    gridLineSubtle: Color(0x11000000),
    textStrong: Color(0xFF0D1421),
    textPrimary: Color(0xFF1E2836),
    textSecondary: Color(0xFF4A5668),
    textTertiary: Color(0xFF78849A),
    textMuted: Color(0xFF6B7789),
    accent: Color(0xFF1268C7),
    onAccent: Color(0xFFFFFFFF),
    link: Color(0xFF0C6FA8),
    positive: Color(0xFF0E8F5C),
    warning: Color(0xFFB26100),
    danger: Color(0xFFC2003F),
    info: Color(0xFF0E7F9B),
    violet: Color(0xFF6B44CF),
    scrim: Color(0x61000000),
    onScrim: Color(0xFFFFFFFF),
  );

  @override
  AppThemeColors copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceMuted,
    Color? surfaceStrong,
    Color? menuBackground,
    Color? disabledSurface,
    Color? cardBorder,
    Color? border,
    Color? gridLine,
    Color? gridLineSubtle,
    Color? textStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textMuted,
    Color? accent,
    Color? onAccent,
    Color? link,
    Color? positive,
    Color? warning,
    Color? danger,
    Color? info,
    Color? violet,
    Color? scrim,
    Color? onScrim,
  }) {
    return AppThemeColors(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceStrong: surfaceStrong ?? this.surfaceStrong,
      menuBackground: menuBackground ?? this.menuBackground,
      disabledSurface: disabledSurface ?? this.disabledSurface,
      cardBorder: cardBorder ?? this.cardBorder,
      border: border ?? this.border,
      gridLine: gridLine ?? this.gridLine,
      gridLineSubtle: gridLineSubtle ?? this.gridLineSubtle,
      textStrong: textStrong ?? this.textStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      link: link ?? this.link,
      positive: positive ?? this.positive,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      violet: violet ?? this.violet,
      scrim: scrim ?? this.scrim,
      onScrim: onScrim ?? this.onScrim,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppThemeColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceElevated: c(surfaceElevated, other.surfaceElevated),
      surfaceMuted: c(surfaceMuted, other.surfaceMuted),
      surfaceStrong: c(surfaceStrong, other.surfaceStrong),
      menuBackground: c(menuBackground, other.menuBackground),
      disabledSurface: c(disabledSurface, other.disabledSurface),
      cardBorder: c(cardBorder, other.cardBorder),
      border: c(border, other.border),
      gridLine: c(gridLine, other.gridLine),
      gridLineSubtle: c(gridLineSubtle, other.gridLineSubtle),
      textStrong: c(textStrong, other.textStrong),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      textMuted: c(textMuted, other.textMuted),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      link: c(link, other.link),
      positive: c(positive, other.positive),
      warning: c(warning, other.warning),
      danger: c(danger, other.danger),
      info: c(info, other.info),
      violet: c(violet, other.violet),
      scrim: c(scrim, other.scrim),
      onScrim: c(onScrim, other.onScrim),
    );
  }
}

/// `context.colors.textPrimary` — the app's colour entry point.
extension AppColorsContext on BuildContext {
  AppThemeColors get colors =>
      Theme.of(this).extension<AppThemeColors>() ?? AppThemeColors.dark;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
