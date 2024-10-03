import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:src/utils/const/constants.dart';
import 'package:src/views/screens/home_screen.dart';
import 'package:src/widgets/window_buttons_widget.dart';

class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return WindowBorder(
      color: AppColors.cardBorderColor,
      width: 2,
      child: Column(
        children: [
          WindowTitleBarBox(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.blackPearlColor,
                    AppColors.backgroundColor,
                    // Colors.blue,
                    // Colors.purple,
                  ],
                  tileMode: TileMode.clamp,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: MoveWindow(),
                  ),
                  WindowButtonsWidget(),
                ],
              ),
            ),
          ),
          Expanded(
            child: HomeScreen(),
          ),
        ],
      ),
    );
  }
}
