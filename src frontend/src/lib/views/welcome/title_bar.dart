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
                  // Todo: convert the battery icon into array and display them according to battery percentage getting from the api for CubeSat and improve UI.
                  Icon(Icons.battery_unknown_outlined),
                  Text(
                    '56%',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.lightSlateGrey,
                    ),
                  ),
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
