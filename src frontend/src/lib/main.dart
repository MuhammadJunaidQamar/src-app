import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:src/theme/dark_theme.dart';
import 'package:src/theme/light_theme.dart';
import 'package:src/theme/theme_manager.dart';
import 'package:src/utils/constants/constants.dart';
import 'package:src/utils/routing/routes.dart';
import 'package:src/utils/routing/routes_name.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!isDesktop) {
    String ACCESS_TOKEN = const String.fromEnvironment("ACCESS_TOKEN");
    mb.MapboxOptions.setAccessToken(ACCESS_TOKEN);
  }
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
      theme: lightTheme(context),
      darkTheme: darkTheme(context),
      themeMode: ThemeMode.system,
      initialRoute: isDesktop ? RouteName.titleBar : RouteName.homeScreen,
      onGenerateRoute: Routes.generateRoute,
    );
  }
}
