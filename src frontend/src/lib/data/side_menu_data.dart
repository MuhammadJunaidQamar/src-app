import 'package:flutter/material.dart';
import 'package:src/model/menu_model.dart';
import 'package:src/utils/constants/constants.dart';

class SideMenuData {
  /// Per-entry brand hues. These are tuned for a dark canvas — the side menu
  /// runs them through `context.colors.tuneAccent()` before painting, so they
  /// stay legible on a white menu too. Keep raw brand values here.
  final menu = const <MenuModel>[
    MenuModel(
      icon: Icons.home,
      title: 'Dashboard',
      color: AppColors.koromikoColor,
    ),
    MenuModel(
      icon: Icons.rocket_launch_sharp,
      title: 'Orientation',
      color: AppColors.tropicalIndigoColor,
    ),
    MenuModel(
      icon: Icons.location_on_sharp,
      title: 'Geo Location',
      color: AppColors.spanishSkyBlueColor,
    ),
    MenuModel(
      icon: Icons.info_outline,
      title: 'Project Info',
      color: AppColors.mediumSeaGreenColor,
    ),
  ];
}
