import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus_winrt/flutter_blue_plus_winrt.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:src/theme/dark_theme.dart';
import 'package:src/theme/light_theme.dart';
import 'package:src/theme/theme_manager.dart';
import 'package:src/utils/constants/constants.dart';
import 'package:src/utils/routing/routes.dart';
import 'package:src/utils/routing/routes_name.dart';
import 'package:src/utils/mapbox_init.dart';
import 'package:src/utils/webview_environment.dart';
import 'package:src/widgets/desktop_window_shell.dart';

final localhostServer = InAppLocalhostServer(documentRoot: 'assets');
ThemeManager themeManager = ThemeManager();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    FlutterBluePlusWinrt.registerWith();
  }

  // InAppLocalhostServer uses dart:io ServerSocket — desktop only.
  if (isNativeDesktop) {
    await localhostServer.start();
  }

  await initializePlatformSpecificSettings();

  runApp(const MyApp());

  if (isNativeDesktop) {
    setupWindow();
  }
}

Future<void> initializePlatformSpecificSettings() async {
  initMapboxSdk();
  if (isNativeDesktop) {
    await setupWebViewEnvironment();
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

/// True on Windows/macOS/Linux builds — false on web even when the browser
/// reports a desktop [defaultTargetPlatform].
bool get isNativeDesktop => !kIsWeb && isDesktop;

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
    if (isNativeDesktop) {
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
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return DesktopWindowShell(child: child);
      },
    );
  }
}
