import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';

class WindowButtonsWidget extends StatelessWidget {
  const WindowButtonsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MinimizeWindowButton(
          animate: true,
        ),
        MaximizeWindowButton(
          animate: true,
        ),
        CloseWindowButton(
          animate: true,
        ),
      ],
    );
  }
}
