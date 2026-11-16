import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Thin wrapper around OS permission prompts used by onboarding.
final class AppPermissionService {
  Future<bool> get notificationsGranted async {
    if (!(Platform.isAndroid || Platform.isIOS)) return true;
    return Permission.notification.isGranted;
  }

  /// Android 13+ lock-screen / media notification prompt. iOS: notification.
  Future<bool> requestNotifications() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return true;
    final status = await Permission.notification.request();
    return status.isGranted || status.isLimited || status.isProvisional;
  }

  Future<void> openSystemSettings() => openAppSettings();
}
