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
    _ => null,
  };
  if (params == null) return;
  if (await RtcCallManager.instance.session.isCallEnded(params.id)) return;
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
  await prefs.setString(
    'cn_call_pending_callkit_target_id',
    extra?['targetId']?.toString() ?? '',
  );
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

    await FlutterCallkitIncoming.onBackgroundMessage(callKitBackgroundHandler);
    _eventSubscription = FlutterCallkitIncoming.onEvent.listen(_handleEvent);
  }

  Future<void> showIncomingCall({
    required String callId,
    required String callerId,
    required String callerName,
    String? targetId,
  }) async {
    if (await RtcCallManager.instance.session.isCallEnded(callId)) return;
    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'CN CALL',
      handle: callerId,
      type: 0,
      duration: 90000,
      callingNotification: const NotificationParams(showNotification: false),
      extra: <String, dynamic>{
        'callerId': callerId,
        'callerName': callerName,
        'callId': callId,
        'targetId': targetId ?? '',
      },
      android: const AndroidParams(
        ringtonePath: 'system_ringtone_default',
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

    // The cancellation can win while the platform method is awaiting. End the
    // native UI again after it returns so a late incoming operation cannot
    // resurrect a terminal call.
    if (await RtcCallManager.instance.session.isCallEnded(callId)) {
      await forceEndCall(callId);
    }
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

    if (id.isEmpty) {
      await endAllCalls();
      return;
    }

    final params = CallKitParams(
      id: id,
      nameCaller: '',
      appName: 'CN CALL',
      handle: '',
    );

    // Stop ringtone immediately.
    try {
      await FlutterCallkitIncoming.hideCallkitIncoming(params);
    } catch (e) {
      print('[CN CALL][CALLKIT] hide incoming failed: $e');
    }

    // End the native CallKit call as well. On Android this sends
    // ACTION_CALL_ENDED, which makes CallkitIncomingActivity finish.
    try {
      await FlutterCallkitIncoming.endCall(id);
    } catch (e) {
      print('[CN CALL][CALLKIT] endCall failed: $e');
      try {
        await FlutterCallkitIncoming.endAllCalls();
      } catch (endAllError) {
        print('[CN CALL][CALLKIT] endAllCalls failed: $endAllError');
      }
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
      // `endCall`/`hideCallkitIncoming` emits this event too.  It is not a
      // user decline, so never recreate a pending reject after a remote
      // cancellation has cleared the call state.
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
    if (await RtcCallManager.instance.session.isCallEnded(params.id)) return;

    final prefs = await SharedPreferences.getInstance();

    // Always persist the action first. This is required when Android
    // launches the Flutter process after the app was terminated.
    await prefs.setString('cn_call_pending_callkit_action', 'accept');
    await prefs.setString('cn_call_pending_callkit_caller_id', callerId);
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

      await RtcCallManager.instance.session.clearPendingCallKitAction(
        params.id,
      );
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
    if (await RtcCallManager.instance.session.isCallEnded(params.id)) return;

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

      await RtcCallManager.instance.session.clearPendingCallKitAction(
        params.id,
      );
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
