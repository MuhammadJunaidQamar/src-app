import 'dart:io' show Platform;

import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

bool get _useDesktopSnackLayout =>
    !kIsWeb &&
    (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

/// Consistent snackbar styling across mobile and desktop.
void showAppSnackBar(
  BuildContext context, {
  required String title,
  required String message,
  required ContentType contentType,
}) {
  const desktopWidth = 380.0;
  final size = MediaQuery.sizeOf(context);
  final horizontalInset =
      ((size.width - desktopWidth) / 2).clamp(12.0, size.width);

  final snackBar = SnackBar(
    elevation: 0,
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    duration: const Duration(seconds: 4),
    dismissDirection: DismissDirection.horizontal,
    // SnackBar forbids setting width and margin together — center via margin only.
    margin: _useDesktopSnackLayout
        ? EdgeInsets.only(top: 12, left: horizontalInset, right: horizontalInset)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    content: AwesomeSnackbarContent(
      title: title,
      message: message,
      contentType: contentType,
    ),
  );

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(snackBar);
}
