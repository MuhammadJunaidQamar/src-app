import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:src/utils/routing/routes_name.dart';

const defaultPadding = 20.0;

const pages = [
  RouteName.dashboardScreen,
  RouteName.orientationScreen,
  RouteName.geoLocationScreen,
  RouteName.projectInfoScreen,
];

class Constants {
  static final String wsUrl = kIsWeb
      ? 'ws://localhost:8765/telemetry'
      : (Platform.isAndroid
          ? 'ws://10.0.2.2:8765/telemetry'
          : 'ws://localhost:8765/telemetry');

  // Deprecated - keeping for backward compatibility
  static final String baseUrl = kIsWeb
      ? 'http://localhost:5000'
      : (Platform.isAndroid ? 'http://10.0.2.2:5000' : 'http://localhost:5000');
  static const String getDataUrl = '/api/SensorData/GetLatestData';
  static const String postDataUrl = '';
  static const String deleteDataUrl = '';
}

class AppText {
  static const String appName = 'Space Research Center';
  static const String appVersion = '';
}

extension ColorExtension on Color {
  /// Convert the color to a darken color based on the [percent]
  Color darken([int percent = 40]) {
    assert(1 <= percent && percent <= 100);
    final value = 1 - percent / 100;
    return Color.fromARGB(
      alpha,
      (red * value).round(),
      (green * value).round(),
      (blue * value).round(),
    );
  }
}

class AppColors {
  static const backgroundColor = eigengrauColor;
  static const cardBorderColor = squidInkColor;
  static const themeColor = eigengrauColor;
  static const textColor = zincColor;
  static const cardBackgroundColor = eigengrauColor;
  static const primaryColor = Color(0xFF2697FF);
  static const secondaryColor = Color(0xFFFFFFFF);
  static const selectionColor = Color(0xFF88B2AC);

  static const Color primary = contentColorCyan;
  static const Color menuBackground = Color(0xFF090912);
  static const Color itemsBackground = Color(0xFF1B2339);
  static const Color pageBackground = Color(0xFF282E45);
  static const Color mainTextColor1 = Colors.white;
  static const Color mainTextColor2 = Colors.white70;
  static const Color mainTextColor3 = Colors.white38;
  static const Color mainGridLineColor = Colors.white10;
  static const Color borderColor = Colors.white54;
  static const Color gridLinesColor = Color(0x11FFFFFF);

  static const Color contentColorBlack = Colors.black;
  static const Color contentColorWhite = Colors.white;
  static const Color contentColorBlue = Color(0xFF2196F3);
  static const Color contentColorYellow = Color(0xFFFFC300);
  static const Color contentColorOrange = Color(0xFFFF683B);
  static const Color contentColorGreen = Color(0xFF3BFF49);
  static const Color contentColorPurple = Color(0xFF6E1BFF);
  static const Color contentColorPink = Color(0xFFFF3AF2);
  static const Color contentColorRed = Color(0xFFE80054);
  static const Color contentColorCyan = Color(0xFF50E4FF);

  static const blackPearlColor = Color.fromARGB(255, 22, 31, 44);
  static const lightSlateGrey =
      Color.fromARGB(255, 128, 140, 156); // less important text
  static const zincColor = Color.fromARGB(255, 191, 199, 210); //
  static const eigengrauColor = Color.fromARGB(255, 16, 21, 29); //
  static const squidInkColor = Color.fromARGB(255, 46, 60, 81);
  static const spanishSkyBlueColor = Color.fromARGB(225, 37, 166, 233); //links
  static const mediumSlateBlueColor = Color.fromARGB(255, 137, 100, 232); //
  static const tropicalIndigoColor =
      Color.fromARGB(255, 168, 127, 251); //button Color
  static const mediumSeaGreenColor = Color.fromARGB(255, 23, 184, 119); //
  static const deepSaffronColor = Color.fromARGB(255, 255, 162, 62); //
  static const topazColor = Color.fromARGB(255, 255, 195, 110); //
  static const koromikoColor = Color.fromARGB(255, 255, 194, 110); //
  static const pantoneColor = Color.fromARGB(255, 108, 74, 254); //switch color
}
