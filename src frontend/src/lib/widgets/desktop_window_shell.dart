import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:src/theme/app_theme_colors.dart';
import 'package:src/widgets/window_buttons_widget.dart';

/// Custom title bar + min/max/close for Windows/macOS/Linux (bitsdojo_window).
class DesktopWindowShell extends StatelessWidget {
  const DesktopWindowShell({super.key, required this.child});

  final Widget child;

  static bool get isActive {
    if (kIsWeb) return false;
    return {
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    }.contains(defaultTargetPlatform);
  }

  @override
  Widget build(BuildContext context) {
    if (!isActive) return child;

    final colors = context.colors;

    return WindowBorder(
      color: colors.cardBorder,
      width: 2,
      child: Column(
        children: [
          WindowTitleBarBox(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.surfaceElevated,
                    colors.background,
                  ],
                  tileMode: TileMode.clamp,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.battery_unknown_outlined,
                    color: colors.textMuted,
                  ),
                  Text(
                    '56%',
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.textMuted,
                    ),
                  ),
                  Expanded(child: MoveWindow()),
                  const WindowButtonsWidget(),
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
