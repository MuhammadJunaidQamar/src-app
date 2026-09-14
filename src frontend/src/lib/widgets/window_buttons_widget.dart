import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:src/theme/app_theme_colors.dart';
import 'package:src/utils/constants/constants.dart';

class WindowButtonsWidget extends StatelessWidget {
  const WindowButtonsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final buttonColors = WindowButtonColors(
      iconNormal: colors.textPrimary,
      // Color of the button when the mouse is hovering over it
      mouseOver: colors.tuneAccent(AppColors.pantoneColor),
      // Color of the button when it is pressed down
      mouseDown: colors.tuneAccent(AppColors.mediumSlateBlueColor),
      // Color of the icon when the button is hovered over
      iconMouseOver: colors.onAccent,
      // Color of the icon when the button is pressed down
      iconMouseDown: colors.onAccent,
    );

    final closeButtonColors = WindowButtonColors(
      // Color of the close button when the mouse is hovering over it
      mouseOver: colors.tuneAccent(_closeRed),
      // Color of the close button when it is pressed down
      mouseDown: colors.tuneAccent(_closePressedRed),
      // Color of the icon in the close button when in its normal state
      iconNormal: colors.textPrimary,
      // Color of the icon in the close button when the mouse is hovering over it
      iconMouseOver: colors.onAccent,
      // Color of the icon in the close button when it is pressed down
      iconMouseDown: colors.onAccent,
    );

    return Row(
      children: [
        MinimizeWindowButton(
          animate: true,
          colors: buttonColors,
        ),
        MaximizeWindowButton(
          colors: buttonColors,
          animate: true,
        ),
        CloseWindowButton(
          colors: closeButtonColors,
          animate: true,
        ),
      ],
    );
  }
}

/// Window-chrome close reds. They are OS chrome rather than brand colour, so
/// they stay literals here; `tuneAccent` deepens them for the light theme,
/// where both still carry a white glyph.
const Color _closeRed = Color(0xFFD32F2F);
const Color _closePressedRed = Color(0xFFB71C1C);
