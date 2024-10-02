import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:src/theme/theme_manager.dart';
import 'package:src/utils/const/constants.dart';
import 'package:src/utils/routing/routes.dart';
import 'package:src/utils/routing/routes_name.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io' show Platform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!(kIsWeb || Platform.isAndroid || Platform.isIOS)) {
    await setupWindowManager();
  }

  runApp(const MyApp());
}

Future<void> setupWindowManager() async {
  if (Platform.isWindows ||
      Platform.isLinux ||
      Platform.isMacOS ||
      Platform.isFuchsia) {
    try {
      await windowManager.ensureInitialized();
      windowManager.setMinimumSize(const Size(600, 750));
    } catch (error) {
      debugPrint("Failed to initialize window manager: $error");
    }
  }
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
        scaffoldBackgroundColor: AppColors.themeColor,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      initialRoute: RouteName.homeScreen,
      onGenerateRoute: Routes.generateRoute,
    );
  }
}
