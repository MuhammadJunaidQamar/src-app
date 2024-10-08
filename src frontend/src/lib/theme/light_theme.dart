import 'package:flutter/material.dart';

ThemeData lightTheme(BuildContext context) {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      shadowColor: Colors.grey,
    ),
    colorScheme: const ColorScheme.light(
      surface: Colors.white,
      primary: Colors.deepOrange,
      secondary: Colors.deepOrangeAccent,
    ),
  );
}
