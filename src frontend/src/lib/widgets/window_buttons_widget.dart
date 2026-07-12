import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:src/utils/constants/constants.dart';

class WindowButtonsWidget extends StatelessWidget {
  WindowButtonsWidget({super.key});

  @override
  Widget build(BuildContext context) {
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

  final buttonColors = WindowButtonColors(
    iconNormal: AppColors.contentColorWhite,
    // Color of the button when the mouse is hovering over it
    mouseOver: AppColors.pantoneColor,
    // Color of the button when it is pressed down
    mouseDown: AppColors.zincColor,
    // Color of the icon when the button is hovered over
    iconMouseOver: AppColors.lightSlateGrey,
    // Color of the icon when the button is pressed down
    iconMouseDown: AppColors.lightSlateGrey,
  );

  final closeButtonColors = WindowButtonColors(
    // Color of the close button when the mouse is hovering over it
    mouseOver: const Color(0xFFD32F2F),
    // Color of the close button when it is pressed down
    mouseDown: const Color(0xFFB71C1C),
    // Color of the icon in the close button when in its normal state
    iconNormal: AppColors.contentColorWhite,
    // Color of the icon in the close button when the mouse is hovering over it
    iconMouseOver: Colors.white,
  );
}
