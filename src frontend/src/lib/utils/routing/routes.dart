import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:src/model/chart_model.dart';
import 'package:src/utils/connection/connection_config.dart';
import 'package:src/utils/global/global.dart';
import 'package:src/utils/routing/routes_name.dart';
import 'package:src/view_model/view_model.dart';
import 'package:src/views/screens/dashboard_screen.dart';
import 'package:src/views/screens/geo_location_screen.dart';
import 'package:src/views/screens/line_chart_display_screen.dart';
import 'package:src/views/screens/globe_screen.dart';
import 'package:src/views/screens/orientation_screen.dart';
import 'package:src/views/screens/home_screen.dart';
import 'package:src/views/screens/connection_mode_screen.dart';
import 'package:src/views/screens/ground_station_pairing_screen.dart';
import 'package:src/views/screens/project_info_screen.dart';
import 'package:src/views/welcome/title_bar.dart';

class Routes {
  static bool get isDesktopTarget {
    if (kIsWeb) return false;
    return {
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    }.contains(defaultTargetPlatform);
  }

  /// Clears the onboarding stack and opens the main shell in one transition.
  static void goToMainApp(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      isDesktopTarget ? RouteName.titleBar : RouteName.homeScreen,
      (route) => false,
    );
  }

  /// Disconnect telemetry and return to connection mode selection.
  static Future<void> goToConnectionMode(BuildContext context) async {
    ConnectionConfig.resetSelection();
    await ViewModel().disconnectForModeChange();
    Global.pageIdx = 0;
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      RouteName.connectionModeScreen,
      (route) => false,
    );
  }

  static Widget getPage(String routeName, {Object? arguments}) {
    switch (routeName) {
      case RouteName.connectionModeScreen:
        return const ConnectionModeScreen();
      case RouteName.groundStationPairingScreen:
        return const GroundStationPairingScreen();
      case RouteName.homeScreen:
        return const HomeScreen();
      case RouteName.dashboardScreen:
        return const DashboardScreen();
      case RouteName.geoLocationScreen:
        return const GeoLocationScreen();
      case RouteName.orientationScreen:
        return const OrientationScreen();
      case RouteName.lineChartDisplayScreen:
        final chartModel = arguments as ChartModel;
        return LineChartDisplayScreen(chartModel: chartModel);
      case RouteName.projectInfoScreen:
        return ProjectInfoScreen();
      case RouteName.globeScreen:
        return const GlobeScreen();
      case RouteName.titleBar:
        return TitleBar();
      default:
        return const Scaffold(
          body: Center(
            child: Text('No route defined'),
          ),
        );
    }
  }

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final page = getPage(
      settings.name!,
      arguments: settings.arguments,
    );

    // Fade into the main app so onboarding → dashboard feels like one step.
    if (settings.name == RouteName.titleBar ||
        settings.name == RouteName.homeScreen) {
      return PageRouteBuilder(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 280),
      );
    }

    return MaterialPageRoute(
      settings: settings,
      builder: (context) => page,
    );
  }
}
