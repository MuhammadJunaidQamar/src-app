import 'package:flutter/material.dart';
import 'package:src/utils/const/constants.dart';

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
      padding: const EdgeInsets.only(top: 13, bottom: 13, left: 7),
      child: Row(
        children: [
          isDarkTheme ? Icon(Icons.nightlight_round_sharp) : Icon(Icons.sunny),
          SizedBox(
            width: 10,
          ),
          Flexible(
            flex: 3,
            child: Text(
              isDarkTheme ? 'Dark Theme' : 'Light Theme',
              style: textStyle,
              overflow: TextOverflow.visible,
            ),
          ),
          Spacer(),
          Switch.adaptive(
            value: isDarkTheme,
            onChanged: _toggleTheme,
          ),
        ],
      ),
    );
  }
}
