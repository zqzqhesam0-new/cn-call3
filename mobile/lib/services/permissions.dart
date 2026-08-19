import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissions {

  static Future<void> requestAll() async {

    if (kIsWeb) {
      await Permission.microphone.request();
      return;
    }

    await [
      Permission.microphone,
      Permission.camera,
      Permission.notification,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();

  }

}
