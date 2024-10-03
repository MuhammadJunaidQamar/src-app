import 'package:flutter/material.dart';
import 'package:src/model/chart_model.dart';
import 'package:src/utils/routing/routes_name.dart';
import 'package:src/views/screens/dashboard_screen.dart';
import 'package:src/views/screens/geo_location_screen.dart';
import 'package:src/views/screens/line_chart_display_screen.dart';
import 'package:src/views/screens/orientation_screen.dart';
import 'package:src/views/screens/home_screen.dart';
import 'package:src/views/screens/project_info_screen.dart';
import 'package:src/views/welcome/title_bar.dart';

class Routes {
  static Widget getPage(String routeName, {Object? arguments}) {
    switch (routeName) {
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
    return MaterialPageRoute(
      builder: (context) => getPage(
        settings.name!,
        arguments: settings.arguments,
      ),
    );
  }
}
