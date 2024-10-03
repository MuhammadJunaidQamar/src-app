import 'package:flutter/material.dart';
import 'package:src/utils/constants/constants.dart';

class ThemeWidget extends StatefulWidget {
  const ThemeWidget({super.key});

  @override
  State<ThemeWidget> createState() => _ThemeWidgetState();
}

class _ThemeWidgetState extends State<ThemeWidget> {
  bool isDarkTheme = true;

  void _toggleTheme(bool value) {
    setState(() {
      isDarkTheme = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: 16,
      color: AppColors.textColor,
      fontWeight: FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 13, bottom: 13, left: 12),
      child: Row(
        children: [
          isDarkTheme
              ? Icon(
                  Icons.nightlight_round_sharp,
                  color: AppColors.squidInkColor,
                )
              : Icon(
                  Icons.wb_sunny_rounded,
                  color: AppColors.deepSaffronColor,
                ),
          SizedBox(
            width: 10,
          ),
          Expanded(
            child: Text(
              isDarkTheme ? 'Dark Theme' : 'Light Theme',
              style: textStyle,
              overflow: TextOverflow.visible,
              softWrap: true,
            ),
          ),
          Switch.adaptive(
            value: isDarkTheme,
            onChanged: _toggleTheme,
          ),
        ],
      ),
    );
  }
}
