import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:src/theme/theme_manager.dart';
import 'package:src/utils/const/constants.dart';
import 'package:src/utils/routing/routes.dart';
import 'package:src/utils/routing/routes_name.dart';

void main() async {
  runApp(const MyApp());
  if (isDesktop) {
    doWhenWindowReady(() {
      final initialSize = Size(600, 750);
      appWindow.minSize = initialSize;
      appWindow.size = initialSize;
      appWindow.title = AppText.appName;
      appWindow.alignment = Alignment.center;
      appWindow.show();
    });
  }
}

bool get isDesktop => [
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS
    ].contains(defaultTargetPlatform);

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
        scaffoldBackgroundColor: AppColors.themeColor,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      initialRoute: RouteName.titleBar,
      onGenerateRoute: Routes.generateRoute,
    );
  }
}
