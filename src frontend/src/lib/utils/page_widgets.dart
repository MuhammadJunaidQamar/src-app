import 'package:flutter/material.dart';
import 'package:src/utils/routes_name.dart';
import 'package:src/views/screens/dashboard_screen.dart';
import 'package:src/views/screens/geo_location_screen.dart';

Widget getPageWidget(String pages) {
  switch (pages) {
    case RouteName.dashboardScreen:
      return DashboardScreen();
    case RouteName.geoLocationScreen:
      return GeoLocationScreen();
    default:
      return Center(child: Text('No widget defined for this route'));
  }
}
