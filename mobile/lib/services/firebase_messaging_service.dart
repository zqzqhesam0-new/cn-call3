import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import 'call_session.dart';
import 'server_config.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('FCM BACKGROUND MESSAGE: ${message.messageId}');
  print('FCM BACKGROUND DATA: ${message.data}');

  if (message.data['type'] == 'incoming_call') {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'pending_incoming_call',
      jsonEncode(message.data),
    );
  }
}

class FirebaseMessagingService {
  FirebaseMessagingService._();

  static final FirebaseMessagingService instance =
      FirebaseMessagingService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;

  String? _token;

  String? get token => _token;

  Future<String?> initialize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      print(
        'FCM notification permission: ${settings.authorizationStatus}',
      );

      _token = await _messaging.getToken();

      print('FCM TOKEN: $_token');

      if (_token != null && _token!.isNotEmpty) {
        await _sendTokenToServer(_token!);
      }

      await _tokenSubscription?.cancel();

      _tokenSubscription = _messaging.onTokenRefresh.listen(
        (token) async {
          _token = token;

          print('FCM TOKEN REFRESHED: $token');

          await _sendTokenToServer(token);
        },
      );

      await _messageSubscription?.cancel();

      _messageSubscription =
          FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) {
          print(
            'FCM FOREGROUND MESSAGE: ${message.messageId}',
          );

          print(
            'FCM DATA: ${message.data}',
          );
        },
      );

      FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage message) {
          print('FCM OPENED APP');
          print(message.data);

          if (message.data['type'] == 'incoming_call') {
            CallSession.instance.incomingCallFromNotification(
              Map<String, dynamic>.from(message.data),
            );
          }
        },
      );

      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();

      if (initialMessage != null) {
        print('FCM INITIAL MESSAGE');
        print(initialMessage.data);

        if (initialMessage.data['type'] == 'incoming_call') {
          CallSession.instance.incomingCallFromNotification(
            Map<String, dynamic>.from(initialMessage.data),
          );
        }
      }

      return _token;
    } catch (e) {
      print('FCM initialization error: $e');
      return null;
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    final userId = CallSession.instance.userId;

    if (userId == null || userId.isEmpty) {
      print('FCM: user not logged in yet');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${ServerConfig.httpUrl}/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'token': token,
        }),
      );

      print(
        'FCM TOKEN SERVER RESPONSE: ${response.statusCode}',
      );

      print(
        'FCM TOKEN SERVER BODY: ${response.body}',
      );
    } catch (e) {
      print(
        'FCM TOKEN SERVER ERROR: $e',
      );
    }
  }

  Future<void> refreshTokenForCurrentUser() async {
    print('FCM REFRESH CURRENT TOKEN: $_token');

    if (_token == null || _token!.isEmpty) {
      print('FCM TOKEN EMPTY');
      return;
    }

    await _sendTokenToServer(_token!);
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();

    _tokenSubscription = null;
    _messageSubscription = null;
  }
}
