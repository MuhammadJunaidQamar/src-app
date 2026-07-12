import 'package:flutter/material.dart';
import 'package:src/utils/desktop_interaction.dart';

ThemeData lightTheme(BuildContext context) {
  return applyDesktopInteractionTheme(
    ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // colorScheme: const ColorScheme.light(
      //   surface: Colors.white,
      //   primary: Colors.deepOrange,
      //   secondary: Colors.deepOrangeAccent,
      // ),
    ),
  );
}
