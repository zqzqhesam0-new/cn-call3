import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'call_socket.dart';
import 'rtc_call_manager.dart';

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

  Future<void> login({required String id, required String name}) async {
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

    // تنفيذ أي Accept/Reject وصل من CallKit أثناء إغلاق التطبيق.
    await processPendingCallKitAction();

    // Keep an unhandled incoming call until HomeScreen has registered its
    // broadcast listener and can consume it through takePendingIncomingCall.

    // استقبال رسائل المكالمات يتم الآن بواسطة RtcCallManager.

    return true;
  }

  Future<void> incomingCallFromNotification(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('pending_incoming_call', jsonEncode(data));

      _incomingCalls.add(data);
    } catch (e) {
      print('SAVE INCOMING CALL ERROR: $e');
    }
  }

  Future<void> processPendingCallKitAction() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final action = prefs.getString('cn_call_pending_callkit_action');
      final callerId =
          prefs.getString('cn_call_pending_callkit_caller_id');
        final callId =
          prefs.getString('cn_call_pending_callkit_call_id');

      if (action == null ||
          action.isEmpty ||
          callerId == null ||
          callerId.isEmpty) {
        return;
      }

      if (action == 'accept') {
        await RtcCallManager.instance.acceptCall(
          callerId: callerId,
          callId: callId,
        );
      } else if (action == 'reject') {
        await RtcCallManager.instance.rejectCall(
          callerId: callerId,
          callId: callId,
        );
      } else {
        return;
      }

      // Delete the pending action only after the operation succeeds.
      await prefs.remove('cn_call_pending_callkit_action');
      await prefs.remove('cn_call_pending_callkit_caller_id');
      await prefs.remove('cn_call_pending_callkit_call_id');
      await prefs.remove('pending_incoming_call');
    } catch (e) {
      print('PROCESS PENDING CALLKIT ACTION ERROR: $e');
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
