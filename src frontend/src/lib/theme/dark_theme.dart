import 'package:flutter/material.dart';
import 'package:src/utils/constants/constants.dart';

ThemeData darkTheme(BuildContext context) {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.eigengrauColor,
      shadowColor: AppColors.squidInkColor,
    ),
  );
}
