import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'call_socket.dart';

class CallSession {
  CallSession._();

  static final CallSession instance = CallSession._();

  final CallSocket socket = CallSocket();

  final StreamController<Map<String, dynamic>> _incomingCalls =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get incomingCalls => _incomingCalls.stream;

  StreamSubscription<Map<String, dynamic>>? _messageSubscription;

  String? userId;
  String? displayName;

  bool get loggedIn => userId != null;

  Future<void> login({
    required String id,
    required String name,
  }) async {
    userId = id;
    displayName = name;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cn_call_user_id', id);
    await prefs.setString('cn_call_display_name', name);

    await socket.connect(id);

    // استقبال رسائل المكالمات يتم الآن بواسطة RtcCallManager.
  }

  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();

    final id = prefs.getString('cn_call_user_id');
    final name = prefs.getString('cn_call_display_name');

    if (id == null || id.isEmpty || name == null || name.isEmpty) {
      return false;
    }

    userId = id;
    displayName = name;

    await socket.connect(id);

    // استعادة أي مكالمة وصلت أثناء إغلاق التطبيق.
    final pendingCall = prefs.getString('pending_incoming_call');

    if (pendingCall != null && pendingCall.isNotEmpty) {
      try {
        final data = jsonDecode(pendingCall);

        if (data is Map) {
          _incomingCalls.add(
            Map<String, dynamic>.from(data),
          );
        }

        await prefs.remove('pending_incoming_call');
      } catch (e) {
        print('PENDING CALL RESTORE ERROR: $e');
      }
    }

    // استقبال رسائل المكالمات يتم الآن بواسطة RtcCallManager.

    return true;
  }

  Future<void> incomingCallFromNotification(
    Map<String, dynamic> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        'pending_incoming_call',
        jsonEncode(data),
      );

      _incomingCalls.add(data);
    } catch (e) {
      print('SAVE INCOMING CALL ERROR: $e');
    }
  }

  Future<Map<String, dynamic>?> takePendingIncomingCall() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final pending = prefs.getString('pending_incoming_call');

      if (pending == null || pending.isEmpty) {
        return null;
      }

      await prefs.remove('pending_incoming_call');

      final data = jsonDecode(pending);

      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      print('TAKE PENDING CALL ERROR: $e');
    }

    return null;
  }

  Future<void> logout() async {
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    socket.disconnect();

    userId = null;
    displayName = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cn_call_user_id');
    await prefs.remove('cn_call_display_name');
  }

  Future<void> dispose() async {
    socket.disconnect();
  }
}
