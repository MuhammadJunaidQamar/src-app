import 'package:flutter/material.dart';
import 'package:src/views/screens/home_screen.dart';

/// Desktop home route — window chrome is provided by [DesktopWindowShell] in main.dart.
class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
