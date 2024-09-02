import 'package:flutter/material.dart';
import 'package:src/model/menu_model.dart';

class SideMenuData {
  final menu = const <MenuModel>[
    MenuModel(icon: Icons.home, title: 'Dashboard'),
    MenuModel(icon: Icons.rocket_launch_sharp, title: 'Orientation'),
    MenuModel(icon: Icons.location_on_sharp, title: 'Geo Location'),
  ];
}
