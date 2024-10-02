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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      child: Row(
        children: [
          Flexible(
            flex: 2,
            child: Text(
              'Dark Theme',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textColor,
                fontWeight: FontWeight.normal,
              ),
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
