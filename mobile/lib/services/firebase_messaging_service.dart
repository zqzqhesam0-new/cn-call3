import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'call_session.dart';
import 'callkit_service.dart';
import 'server_config.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  print('FCM BACKGROUND MESSAGE: ${message.messageId}');
  print('FCM BACKGROUND DATA: ${message.data}');

  await Firebase.initializeApp();

  final prefs = await SharedPreferences.getInstance();

  final type = message.data['type']?.toString();

  if (type == 'incoming_call') {
    final callerId =
        message.data['caller_id']?.toString() ??
        message.data['from_id']?.toString() ??
        '';

    if (callerId.isEmpty) {
      print('FCM BACKGROUND: missing caller_id');
      return;
    }

    await prefs.setString(
      'pending_incoming_call',
      jsonEncode(message.data),
    );

    try {
      final callId = message.data['call_id']?.toString();
      final callerName =
          message.data['caller_name']?.toString() ?? 'CN CALL';
        final targetId = message.data['target_id']?.toString() ?? '';
      if (callId == null || callId.isEmpty) return;

      await CallKitService.instance.showIncomingCall(
        callId: callId,
        callerId: callerId,
        callerName: callerName,
        targetId: targetId,
      );
      print('FCM BACKGROUND: CallKit incoming call shown');
    } catch (e) {
      print('FCM BACKGROUND CALLKIT ERROR: $e');
    }

    return;
  }

  if (type == 'call_cancelled') {
    final callId = message.data['call_id']?.toString();
    if (callId != null && callId.isNotEmpty) {
      await CallKitService.instance.endCall(callId);
    }
    await prefs.remove('pending_incoming_call');
    print('FCM BACKGROUND: removed pending incoming call');
  }
}

class FirebaseMessagingService {
  FirebaseMessagingService._();

  static final FirebaseMessagingService instance =
      FirebaseMessagingService._();

  final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;

  String? _token;

  String? get token => _token;

  Future<String?> initialize() async {
    try {
      final settings =
          await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      print(
        'FCM notification permission: '
        '${settings.authorizationStatus}',
      );

      _token = await _messaging.getToken();

      print('FCM TOKEN: $_token');

      if (_token != null && _token!.isNotEmpty) {
        await _sendTokenToServer(_token!);
      }

      await _tokenSubscription?.cancel();

      _tokenSubscription =
          _messaging.onTokenRefresh.listen(
        (token) async {
          _token = token;

          print('FCM TOKEN REFRESHED: $token');

          await _sendTokenToServer(token);
        },
      );

      await _messageSubscription?.cancel();

      _messageSubscription =
          FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) async {
          print(
            'FCM FOREGROUND MESSAGE: '
            '${message.messageId}',
          );

          print(
            'FCM FOREGROUND DATA: '
            '${message.data}',
          );

          if (message.data['type'] != 'incoming_call') {
            return;
          }

          final callerId =
              message.data['caller_id']?.toString() ??
              message.data['from_id']?.toString() ??
              '';

          final callerName =
              message.data['caller_name']?.toString() ??
              'CN CALL';
            final targetId = message.data['target_id']?.toString() ?? '';

          if (callerId.isEmpty) return;

          final callId = message.data['call_id']?.toString();
          if (callId == null || callId.isEmpty) return;

          if (CallSession.instance.socket.connected) return;

          await CallKitService.instance.showIncomingCall(
            callId: callId,
            callerId: callerId,
            callerName: callerName,
            targetId: targetId,
          );
        },
      );

      return _token;
    } catch (e) {
      print('FCM initialization error: $e');
      return null;
    }
  }

  Future<void> _sendTokenToServer(
    String token,
  ) async {
    final userId = CallSession.instance.userId;

    if (userId == null || userId.isEmpty) {
      print(
        'FCM: user not logged in yet',
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(
          '${ServerConfig.httpUrl}/fcm-token',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'token': token,
        }),
      );

      print(
        'FCM TOKEN SERVER RESPONSE: '
        '${response.statusCode}',
      );

      print(
        'FCM TOKEN SERVER BODY: '
        '${response.body}',
      );
    } catch (e) {
      print(
        'FCM TOKEN SERVER ERROR: $e',
      );
    }
  }

  Future<void> refreshTokenForCurrentUser() async {
    try {
      final token = await _messaging.getToken();

      if (token == null || token.isEmpty) {
        print('FCM REFRESH: no token');
        return;
      }

      _token = token;

      print('FCM REFRESH TOKEN: $token');

      await _sendTokenToServer(token);
    } catch (e) {
      print(
        'FCM REFRESH ERROR: $e',
      );
    }
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();

    _tokenSubscription = null;
    _messageSubscription = null;
  }
}
