import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import 'call_session.dart';
import 'server_config.dart';

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
    if (_token == null || _token!.isEmpty) {
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
