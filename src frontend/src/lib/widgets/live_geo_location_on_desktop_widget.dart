import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class LiveGeoLocationOnDesktopWidget extends StatefulWidget {
  const LiveGeoLocationOnDesktopWidget({super.key});

  @override
  State<StatefulWidget> createState() => LiveGeoLocationOnDesktopWidgetState();
}

class LiveGeoLocationOnDesktopWidgetState
    extends State<LiveGeoLocationOnDesktopWidget> {
  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const HtmlElementView(viewType: 'assets/webview/mapbox_map.html');
    } else if (Platform.isAndroid) {
      // Android-specific InAppWebView implementation
      return InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(
              'file:///android_asset/flutter_assets/assets/webview/mapbox_map.html'),
        ),
      );
    } else if (Platform.isIOS) {
      // iOS-specific InAppWebView implementation
      return InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(
              'file://Frameworks/App.framework/flutter_assets/assets/webview/mapbox_map.html'),
        ),
      );
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop-specific InAppWebView implementation using localhost server
      return InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri('http://localhost:8080/webview/mapbox_map.html'),
        ),
      );
    } else {
      // Handle unsupported platforms
      return const Center(
        child: Text('Unsupported Platform'),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
    // Make sure to stop the localhost server if it's running
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      InAppLocalhostServer().close();
    }
  }
}
