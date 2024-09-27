import 'package:flutter/material.dart';
import 'package:src/theme/theme_manager.dart';
import 'package:src/utils/const/constants.dart';
import 'package:src/utils/routes.dart';
import 'package:src/utils/routes_name.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io' show Platform;

void main() async {
  if (Platform.isWindows ||
      Platform.isLinux ||
      Platform.isMacOS ||
      Platform.isFuchsia) {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();
    windowManager.setMinimumSize(const Size(600, 750));
  }
  runApp(const MyApp());
}

ThemeManager themeManager = ThemeManager();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    themeManager.removeListener(themeListener);
    super.dispose();
  }

  @override
  void initState() {
    themeManager.addListener(themeListener);
    super.initState();
  }

  themeListener() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppText.appName,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.backgroundColor,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      initialRoute: RouteName.homeScreen,
      onGenerateRoute: Routes.generateRoute,
    );
  }
}
