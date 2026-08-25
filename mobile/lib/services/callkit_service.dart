import 'dart:async';

import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'rtc_call_manager.dart';

@pragma('vm:entry-point')
Future<void> callKitBackgroundHandler(CallEvent event) async {
  final params = switch (event) {
    CallEventActionCallAccept(:final callKitParams) => callKitParams,
    CallEventActionCallDecline(:final callKitParams) => callKitParams,
    CallEventActionCallEnded(:final callKitParams) => callKitParams,
    _ => null,
  };
  if (params == null) return;
  final extra = params.extra;
  final callerId =
      extra?['callerId']?.toString() ?? params.handle?.toString() ?? '';
  if (callerId.isEmpty) return;

  final action = switch (event) {
    CallEventActionCallAccept() => 'accept',
    CallEventActionCallDecline() => 'reject',
    CallEventActionCallEnded() => 'ended',
    CallEventActionCallTimeout() => 'timeout',
    _ => null,
  };
  if (action == null) return;

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('cn_call_pending_callkit_action', action);
  await prefs.setString('cn_call_pending_callkit_caller_id', callerId);
  await prefs.setString('cn_call_pending_callkit_call_id', params.id);
  await prefs.setString('cn_call_pending_callkit_target_id',
      extra?['targetId']?.toString() ?? '');
}

class CallKitService {
  CallKitService._();

  static final CallKitService instance = CallKitService._();

  StreamSubscription<CallEvent?>? _eventSubscription;

  bool _initialized = false;

  Function(String callerId)? onAccepted;
  Function(String callerId)? onRejected;

  String? lastAcceptedCallerId;
  String? lastAcceptedCallId;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await FlutterCallkitIncoming.onBackgroundMessage(
      callKitBackgroundHandler,
    );
    _eventSubscription = FlutterCallkitIncoming.onEvent.listen(_handleEvent);
  }

  Future<void> showIncomingCall({
    required String callId,
    required String callerId,
    required String callerName,
    String? targetId,
  }) async {
    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'CN CALL',
      handle: callerId,
      type: 0,
      duration: 90000,
      callingNotification: const NotificationParams(
        showNotification: false,
      ),
      extra: <String, dynamic>{
        'callerId': callerId,
        'callerName': callerName,
        'callId': callId,
        'targetId': targetId ?? '',
      },
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        isShowCallID: true,
        isShowFullLockedScreen: true,
        isFullScreen: true,
        isImportant: true,
        backgroundColor: '#050505',
        actionColor: '#00E676',
        textColor: '#FFFFFF',
        incomingCallNotificationChannelName: 'CN CALL Incoming Calls',
        missedCallNotificationChannelName: 'CN CALL Missed Calls',
        textAccept: 'قبول',
        textDecline: 'رفض',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  Future<void> endCall(String callId) async {
    if (callId.trim().isEmpty) {
      await endAllCalls();
      return;
    }

    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (e) {
      print('[CN CALL][CALLKIT] endCall failed: $e');
      await endAllCalls();
    }
  }

  Future<void> forceEndCall(String? callId) async {
    final id = callId?.trim() ?? '';

    if (id.isNotEmpty) {
      try {
        await FlutterCallkitIncoming.endCall(id);
      } catch (e) {
        print('[CN CALL][CALLKIT] force end by id failed: $e');
      }
    }

    // Ensures stale "incoming call" UI is removed even when
    // the original CallKit ID is missing or already cleared.
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      print('[CN CALL][CALLKIT] force end all failed: $e');
    }
  }

  Future<void> endAllCalls() async {
    await FlutterCallkitIncoming.endAllCalls();
  }

  Future<void> _handleEvent(CallEvent? event) async {
    if (event == null) return;

    if (event is CallEventActionCallAccept) {
      await _accept(event.callKitParams);
      return;
    }

    if (event is CallEventActionCallDecline) {
      await _reject(event.callKitParams);
      return;
    }

    if (event is CallEventActionCallEnded) {
      await _reject(event.callKitParams);
      return;
    }

    if (event is CallEventActionCallTimeout) {
      await _rejectById(event.id);
      return;
    }

    if (event is CallEventActionCallConnected) {
      await FlutterCallkitIncoming.setCallConnected(event.id);
      return;
    }
  }

  Future<void> _accept(CallKitParams params) async {
    final extra = params.extra;

    final callerId =
        extra?['callerId']?.toString() ?? params.handle?.toString();

    if (callerId == null || callerId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    // Always persist the action first. This is required when Android
    // launches the Flutter process after the app was terminated.
    await prefs.setString(
      'cn_call_pending_callkit_action',
      'accept',
    );
    await prefs.setString(
      'cn_call_pending_callkit_caller_id',
      callerId,
    );
    await prefs.setString('cn_call_pending_callkit_call_id', params.id);

    // If Flutter is already running and the user is logged in,
    // execute the accept immediately.
    if (!RtcCallManager.instance.session.loggedIn) {
      return;
    }

    try {
      await RtcCallManager.instance.acceptCall(
        callerId: callerId,
        callId: params.id,
      );

      lastAcceptedCallerId = callerId;
      lastAcceptedCallId = params.id;
      onAccepted?.call(callerId);

      await prefs.remove('cn_call_pending_callkit_action');
      await prefs.remove('cn_call_pending_callkit_caller_id');
    } catch (e) {
      print('CALLKIT ACCEPT ERROR: $e');

      // Keep the pending action so it can be retried after
      // the Flutter session is restored.
    }
  }

  Future<void> _reject(CallKitParams params) async {
    final extra = params.extra;

    final callerId =
        extra?['callerId']?.toString() ?? params.handle?.toString();

    if (callerId == null || callerId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('cn_call_pending_callkit_action', 'reject');
    await prefs.setString('cn_call_pending_callkit_caller_id', callerId);
    await prefs.setString('cn_call_pending_callkit_call_id', params.id);

    // If Flutter is already running, execute immediately.
    if (RtcCallManager.instance.session.loggedIn) {
      await RtcCallManager.instance.rejectCall(
        callerId: callerId,
        callId: params.id,
      );

      onRejected?.call(callerId);

      await prefs.remove('cn_call_pending_callkit_action');
      await prefs.remove('cn_call_pending_callkit_caller_id');
    }
  }

  Future<void> _rejectById(String callId) async {
    final activeCalls = await FlutterCallkitIncoming.activeCalls();

    for (final call in activeCalls) {
      if (call.id != callId) continue;

      final extra = call.extra;
      final callerId =
          extra?['callerId']?.toString() ?? call.handle?.toString();

      if (callerId != null && callerId.isNotEmpty) {
        await RtcCallManager.instance.rejectCall(
          callerId: callerId,
          callId: call.id,
        );
      }

      break;
    }
  }

  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _initialized = false;
  }
}
