import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool get isDesktopPlatform {
  if (kIsWeb) return false;
  return {
    TargetPlatform.windows,
    TargetPlatform.macOS,
    TargetPlatform.linux,
  }.contains(defaultTargetPlatform);
}

const MouseCursor clickCursor = SystemMouseCursors.click;

WidgetStateProperty<MouseCursor> get clickCursorState =>
    WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return SystemMouseCursors.basic;
      }
      return SystemMouseCursors.click;
    });

/// Adds a pointer cursor to interactive components on desktop, *merging* into
/// whatever the caller already configured so palette-driven component themes
/// survive.
ThemeData applyDesktopInteractionTheme(ThemeData theme) {
  if (!isDesktopPlatform) return theme;

  ButtonStyle withCursor(ButtonStyle? style) =>
      (style ?? const ButtonStyle()).copyWith(mouseCursor: clickCursorState);

  return theme.copyWith(
    iconButtonTheme:
        IconButtonThemeData(style: withCursor(theme.iconButtonTheme.style)),
    elevatedButtonTheme: ElevatedButtonThemeData(
        style: withCursor(theme.elevatedButtonTheme.style)),
    textButtonTheme:
        TextButtonThemeData(style: withCursor(theme.textButtonTheme.style)),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: withCursor(theme.outlinedButtonTheme.style)),
    filledButtonTheme:
        FilledButtonThemeData(style: withCursor(theme.filledButtonTheme.style)),
    listTileTheme: theme.listTileTheme.copyWith(mouseCursor: clickCursorState),
    switchTheme: theme.switchTheme.copyWith(mouseCursor: clickCursorState),
    checkboxTheme: theme.checkboxTheme.copyWith(mouseCursor: clickCursorState),
    radioTheme: theme.radioTheme.copyWith(mouseCursor: clickCursorState),
    menuButtonTheme:
        MenuButtonThemeData(style: withCursor(theme.menuButtonTheme.style)),
  );
}

/// Wraps [child] with a pointer cursor on desktop when [enabled] is true.
Widget withClickCursor(Widget child, {bool enabled = true}) {
  if (!isDesktopPlatform || !enabled) return child;
  return MouseRegion(cursor: clickCursor, child: child);
}
