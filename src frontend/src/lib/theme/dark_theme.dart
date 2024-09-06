import 'package:flutter/material.dart';
import 'package:src/utils/const/constants.dart';

ThemeData darkTheme(BuildContext context) {
  double screenWidth = MediaQuery.of(context).size.width;

  double fontSizeMultiplier = screenWidth / 400;

  double responsiveFontSize(double fontSize) {
    return fontSize * fontSizeMultiplier;
  }

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.eigengrauColor,
      shadowColor: AppColors.squidInkColor,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.eigengrauColor),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(
            horizontal: 40 * fontSizeMultiplier,
            vertical: 10 * fontSizeMultiplier,
          ),
        ),
        //   enableFeedback: true,
        // textStyle: MaterialStateProperty.all<TextStyle>(
        //   const TextStyle(
        //     color: eigengrauColor,
        //     fontWeight: FontWeight.bold,
        //     fontSize: 24,
        //   ),
        // ),
        shape: MaterialStateProperty.all<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50 * fontSizeMultiplier),
          ),
        ),
        backgroundColor:
            MaterialStateProperty.all<Color>(AppColors.tropicalIndigoColor),
      ),
    ),
    textTheme: TextTheme(
      headlineSmall: TextStyle(
        color: AppColors.zincColor,
        fontSize: responsiveFontSize(17),
      ),
      headlineLarge: TextStyle(
        color: AppColors.zincColor,
        fontWeight: FontWeight.bold,
        fontSize: responsiveFontSize(24),
      ),
      headlineMedium: TextStyle(
        color: AppColors.zincColor,
        fontWeight: FontWeight.bold,
        fontSize: responsiveFontSize(20),
      ),
      displaySmall: TextStyle(
        color: AppColors.lightSlateGrey,
        fontSize: responsiveFontSize(16),
      ),
    ),
    switchTheme: SwitchThemeData(
      //   trackOutlineColor:
      //     MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
      //   if (states.contains(MaterialState.selected)) {
      //     return mediumSeaGreenColor;
      //   }
      //   return deepSaffronColor;
      // }),
      thumbColor: MaterialStateProperty.all(AppColors.tropicalIndigoColor),
      trackColor: MaterialStateProperty.all(AppColors.mediumSlateBlueColor),
    ),
    primaryTextTheme: TextTheme(
      bodyLarge: TextStyle(
        color: AppColors.spanishSkyBlueColor,
        fontSize: responsiveFontSize(20),
      ),
      bodyMedium: TextStyle(
        color: AppColors.lightSlateGrey,
        fontSize: responsiveFontSize(18),
      ),
      bodySmall: TextStyle(
        color: AppColors.lightSlateGrey,
        fontSize: responsiveFontSize(16),
      ),
      displaySmall: TextStyle(
        color: AppColors.lightSlateGrey,
        fontSize: responsiveFontSize(24),
      ),
      headlineLarge: TextStyle(
        color: AppColors.zincColor,
        fontWeight: FontWeight.bold,
        fontSize: responsiveFontSize(24),
      ),
      headlineSmall: TextStyle(
        color: AppColors.zincColor,
        fontWeight: FontWeight.bold,
        fontSize: responsiveFontSize(18),
      ),
      headlineMedium: TextStyle(
        color: AppColors.zincColor,
        fontWeight: FontWeight.bold,
        fontSize: responsiveFontSize(20),
      ),
    ),
    colorScheme: const ColorScheme.dark(
      background: AppColors.eigengrauColor,
      primary: AppColors.blackPearlColor,
      secondary: AppColors.squidInkColor,
    ),
  );
}
