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

ThemeData applyDesktopInteractionTheme(ThemeData theme) {
  if (!isDesktopPlatform) return theme;

  final interactiveButtonStyle = ButtonStyle(
    mouseCursor: clickCursorState,
  );

  return theme.copyWith(
    iconButtonTheme: IconButtonThemeData(style: interactiveButtonStyle),
    elevatedButtonTheme: ElevatedButtonThemeData(style: interactiveButtonStyle),
    textButtonTheme: TextButtonThemeData(style: interactiveButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: interactiveButtonStyle),
    filledButtonTheme: FilledButtonThemeData(style: interactiveButtonStyle),
    listTileTheme: ListTileThemeData(mouseCursor: clickCursorState),
    switchTheme: SwitchThemeData(mouseCursor: clickCursorState),
    checkboxTheme: CheckboxThemeData(mouseCursor: clickCursorState),
    radioTheme: RadioThemeData(mouseCursor: clickCursorState),
    menuButtonTheme: MenuButtonThemeData(style: interactiveButtonStyle),
  );
}

/// Wraps [child] with a pointer cursor on desktop when [enabled] is true.
Widget withClickCursor(Widget child, {bool enabled = true}) {
  if (!isDesktopPlatform || !enabled) return child;
  return MouseRegion(cursor: clickCursor, child: child);
}
