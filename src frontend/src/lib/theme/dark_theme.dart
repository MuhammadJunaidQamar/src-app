import 'package:flutter/material.dart';
import 'package:src/utils/desktop_interaction.dart';

ThemeData darkTheme(BuildContext context) {
  return applyDesktopInteractionTheme(
    ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
    ),
  );
}
