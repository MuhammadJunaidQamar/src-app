import 'package:flutter/material.dart';
import 'package:src/utils/routes_name.dart';
import 'package:src/views/screens/dashboard_screen.dart';
import 'package:src/views/screens/geo_location_screen.dart';
import 'package:src/views/screens/orientation_screen.dart';
import 'package:src/views/screens/home_screen.dart';

class Routes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteName.homeScreen:
        return MaterialPageRoute(builder: (context) => const HomeScreen());
      case RouteName.dashboardscreen:
        return MaterialPageRoute(builder: (context) => const DashboardScreen());
      case RouteName.geolocationscreen:
        return MaterialPageRoute(
            builder: (context) => const GeoLocationScreen());
      case RouteName.orientationscreen:
        return MaterialPageRoute(
            builder: (context) => const OrientationScreen());
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
