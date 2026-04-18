import 'package:flutter/material.dart';
import 'package:src/main.dart';
import 'package:src/utils/constants/constants.dart';

class ThemeWidget extends StatefulWidget {
  const ThemeWidget({super.key});

  @override
  State<ThemeWidget> createState() => _ThemeWidgetState();
}

class _ThemeWidgetState extends State<ThemeWidget> {
  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: 16,
      color: AppColors.textColor,
      fontWeight: FontWeight.normal,
      letterSpacing: 0.0,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 13, bottom: 13, left: 12),
      child: SwitchListTile.adaptive(
        value: themeManager.themeMode == ThemeMode.dark,
        onChanged: (value) {
          setState(() {
            themeManager.toggleTheme(value);
          });
        },
        title: Text(
          themeManager.themeMode == ThemeMode.dark
              ? 'Dark Theme'
              : 'Light Theme',
          style: textStyle,
          maxLines: 2,
          softWrap: true,
          overflow: TextOverflow.visible,
        ),
        secondary: themeManager.themeMode == ThemeMode.dark
            ? Icon(
                Icons.nightlight_round_sharp,
                color: AppColors.squidInkColor,
              )
            : Icon(
                Icons.wb_sunny_rounded,
                color: AppColors.deepSaffronColor,
              ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
