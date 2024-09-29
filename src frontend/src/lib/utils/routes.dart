import 'package:flutter/material.dart';
import 'package:src/model/chart_model.dart';
import 'package:src/utils/routes_name.dart';
import 'package:src/views/screens/dashboard_screen.dart';
import 'package:src/views/screens/geo_location_screen.dart';
import 'package:src/views/screens/line_chart_display_screen.dart';
import 'package:src/views/screens/orientation_screen.dart';
import 'package:src/views/screens/home_screen.dart';

class Routes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteName.homeScreen:
        return MaterialPageRoute(builder: (context) => const HomeScreen());
      case RouteName.dashboardScreen:
        return MaterialPageRoute(builder: (context) => const DashboardScreen());
      case RouteName.geoLocationScreen:
        return MaterialPageRoute(
            builder: (context) => const GeoLocationScreen());
      case RouteName.orientationScreen:
        return MaterialPageRoute(
            builder: (context) => const OrientationScreen());
      case RouteName.lineChartDisplayScreen:
        final chartModel = settings.arguments as ChartModel;
        return MaterialPageRoute(
            builder: (context) =>
                LineChartDisplayScreen(chartModel: chartModel));
      default:
        return MaterialPageRoute(
          builder: ((context) {
            return const Scaffold(
              body: Center(
                child: Text('No route defined'),
              ),
            );
          }),
        );
    }
  }
}
