import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:src/theme/dark_theme.dart';
import 'package:src/theme/light_theme.dart';
import 'package:src/theme/theme_manager.dart';
import 'package:src/utils/constants/constants.dart';
import 'package:src/utils/routing/routes.dart';
import 'package:src/utils/routing/routes_name.dart';
import 'package:src/utils/mapbox_init.dart';

final localhostServer = InAppLocalhostServer(documentRoot: 'assets');
WebViewEnvironment? webViewEnvironment;
ThemeManager themeManager = ThemeManager();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start the localhost server for serving HTML assets
  await localhostServer.start();

  await initializePlatformSpecificSettings();

  runApp(const MyApp());

  if (isDesktop) {
    setupWindow();
  }
}

Future<void> initializePlatformSpecificSettings() async {
  if (isDesktop) {
    await setupWebViewEnvironment();
  } else if (!kIsWeb) {
    if (isMobile) {
      initMapboxSdk();
    }
  }
}

Future<void> setupWebViewEnvironment() async {
  try {
    final availableVersion = await WebViewEnvironment.getAvailableVersion();
    if (availableVersion == null) {
      throw Exception('Failed to find WebView2 runtime.');
    }
    webViewEnvironment = await WebViewEnvironment.create(
      settings: WebViewEnvironmentSettings(
        userDataFolder: 'C:/Users/muham/Documents/webview/EBWebView',
      ),
    );
  } catch (e) {
    debugPrint('Error setting up WebView: $e');
  }
}

void setupWindow() {
  doWhenWindowReady(() {
    final initialSize = const Size(600, 750);
    appWindow.minSize = initialSize;
    appWindow.size = initialSize;
    appWindow.title = AppText.appName;
    appWindow.alignment = Alignment.center;
    appWindow.show();
  });
}

bool get isDesktop => [
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS
    ].contains(defaultTargetPlatform);

bool get isMobile => [TargetPlatform.iOS, TargetPlatform.android]
    .contains(defaultTargetPlatform);

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    themeManager.addListener(themeListener);
    super.initState();
  }

  @override
  void dispose() {
    themeManager.removeListener(themeListener);
    if (isDesktop) {
      localhostServer.close();
    }
    super.dispose();
  }

  void themeListener() {
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
      initialRoute: RouteName.connectionModeScreen,
      onGenerateRoute: Routes.generateRoute,
    );
  }
}
