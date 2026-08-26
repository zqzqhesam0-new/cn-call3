// ignore_for_file: avoid_print

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:uuid/uuid.dart';

import 'call_session.dart';
import 'callkit_service.dart';
import 'livekit_call.dart';
import 'livekit_token_service.dart';

enum CallState {
  incoming,
  ringing,
  accepted,
  rejected,
  cancelled,
  connecting,
  connected,
  ended,
  timeout,
  offline,
}

class RtcCallManager {
  RtcCallManager._();

  static final RtcCallManager instance = RtcCallManager._();

  final CallSession session = CallSession.instance;
  final LiveKitCall livekit = LiveKitCall();

  final AudioPlayer _ringPlayer = AudioPlayer();
  bool _ringing = false;
  Timer? _ringTimeoutTimer;
  Timer? _negotiationTimeoutTimer;
  Timer? _connectionTimeoutTimer;

  StreamSubscription<Map<String, dynamic>>? _subscription;

  String? remoteUserId;
  String? currentCallId;
  bool? remoteOnline;
  CallState? state;
  bool inCall = false;
  bool caller = false;

  final List<Map<String, dynamic>> _pendingIceCandidates = [];

  Function()? onConnected;
  Function()? onDisconnected;
  Function(Map<String, dynamic> message)? onIncomingCall;
  Function(String callId)? onRemoteCallCancelled;
  Function(bool online)? onRemoteAvailabilityChanged;

  bool _started = false;
  bool _hangingUp = false;
  Completer<bool>? _callStartCompleter;
  int? _callStartExpiresAt;

  Future<void> _startRinging({int? expiresAt}) async {
    final wasRinging = _ringing;

    _ringing = true;

    _ringTimeoutTimer?.cancel();

    Duration duration = const Duration(seconds: 90);

    if (expiresAt != null) {
      final remainingMs = expiresAt - DateTime.now().millisecondsSinceEpoch;

      if (remainingMs <= 0) {
        await _handleRingTimeout();
        return;
      }

      final cappedMs = remainingMs > 90000 ? 90000 : remainingMs;
      duration = Duration(milliseconds: cappedMs);
    }

    _ringTimeoutTimer = Timer(
      duration,
      _handleRingTimeout,
    );

    try {
      if (!wasRinging) {
        await _ringPlayer.stop();
        await _ringPlayer.setReleaseMode(ReleaseMode.loop);
        await _ringPlayer.play(
          AssetSource('sounds/ringing.mp3'),
          ctx: AudioContextConfig(
            route: AudioContextConfigRoute.earpiece,
          ).build(),
        );
        print('[CN CALL][RING] started');
      }
    } catch (e) {
      _ringing = false;
      _ringTimeoutTimer?.cancel();
      _ringTimeoutTimer = null;
      print('[CN CALL][RING] start error: $e');
    }
  }

  Future<void> _stopRinging() async {
    _ringTimeoutTimer?.cancel();
    _ringTimeoutTimer = null;

    if (!_ringing) return;

    _ringing = false;

    try {
      await _ringPlayer.stop();
      print('[CN CALL][RING] stopped');
    } catch (e) {
      print('[CN CALL][RING] stop error: $e');
    }
  }

  void _cancelCallTimeouts() {
    _ringTimeoutTimer?.cancel();
    _ringTimeoutTimer = null;
    _negotiationTimeoutTimer?.cancel();
    _negotiationTimeoutTimer = null;
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = null;
  }

  void _startNegotiationTimeout(String callId) {
    _negotiationTimeoutTimer?.cancel();
    _negotiationTimeoutTimer = Timer(
      const Duration(seconds: 30),
      () => _handleNegotiationTimeout(callId),
    );
  }

  void _startConnectionTimeout(String callId) {
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = Timer(
      const Duration(seconds: 30),
      () => _handleConnectionTimeout(callId),
    );
  }

  Future<void> _handleNegotiationTimeout(String callId) async {
    if (!_isCurrentCall(callId) ||
        state == CallState.connected ||
        state == CallState.ended) {
      return;
    }

    print('[CN CALL][TIMEOUT] negotiation call_id=$callId');
    await _cleanupCall(
      reason: 'timeout',
      sendSignal: true,
      signalType: 'hangup',
    );
  }

  Future<void> _handleConnectionTimeout(String callId) async {
    if (!_isCurrentCall(callId) ||
        state == CallState.connected ||
        state == CallState.ended) {
      return;
    }

    print('[CN CALL][TIMEOUT] connection call_id=$callId');
    await _cleanupCall(
      reason: 'timeout',
      sendSignal: true,
      signalType: 'hangup',
    );
  }

  Future<void> _handleRingTimeout() async {
    if (!caller || inCall || currentCallId == null) return;

    print('[CN CALL][RING] timeout reached');

    await _cleanupCall(
      reason: 'timeout',
      sendSignal: true,
      signalType: 'call_cancelled',
    );
  }

  void startListening() {
    if (_started) return;
    _started = true;

    _subscription = session.socket.messages.listen(_handleMessage);

    livekit.onConnected = () {
      final connectedCallId = currentCallId;
      final target = remoteUserId;

      _cancelCallTimeouts();
      inCall = true;
      state = CallState.connected;

      print(
        '[CN CALL][LIVEKIT MANAGER] connected '
        'call_id=$connectedCallId',
      );

      if (connectedCallId != null &&
          connectedCallId.isNotEmpty &&
          target != null &&
          target.isNotEmpty &&
          session.loggedIn &&
          session.socket.connected) {
        session.socket.send({
          'type': 'connected',
          'call_id': connectedCallId,
          'target_id': target,
          'from_id': session.userId,
        });
      }

      onConnected?.call();
    };

    livekit.onDisconnected = () {
      if (_hangingUp) return;

      print(
        '[CN CALL][LIVEKIT MANAGER] disconnected '
        'call_id=$currentCallId',
      );

      unawaited(
        _cleanupCall(
          reason: 'failed',
          sendSignal: true,
          signalType: 'hangup',
        ),
      );
    };
  }

  Future<void> _handleMessage(Map<String, dynamic> message) async {
    final type = message['type']?.toString();
    final messageCallId = message['call_id']?.toString().trim();

    if (type == 'call') {
      if (messageCallId == null ||
          messageCallId.isEmpty ||
          await session.isCallEnded(messageCallId) ||
          currentCallId != null) {
        return;
      }
      currentCallId = messageCallId;
      await session.markCallActive(messageCallId);
      state = CallState.incoming;
      remoteUserId = message['from_id']?.toString();

      onIncomingCall?.call(message);
      return;
    }

    if (type == 'call_started') {
      if (!_isCurrentCall(messageCallId)) return;

      remoteOnline = message['target_online'] == true;
      onRemoteAvailabilityChanged?.call(remoteOnline!);

      // Offline does NOT mean the call failed.
      // The server has already created the call and sent FCM.
      // Keep the caller ringing until the server-provided 90s expiry.
      state = CallState.ringing;

      final expiresAtRaw = message['ring_expires_at'];
      _callStartExpiresAt = expiresAtRaw is int
          ? expiresAtRaw
          : int.tryParse(expiresAtRaw?.toString() ?? '');

      await _startRinging(expiresAt: _callStartExpiresAt);

      // call_started itself confirms that the server accepted the call.
      // target_online only tells us whether the target has a live WebSocket.
      _callStartCompleter?.complete(true);
      _callStartCompleter = null;

      return;
    }

    if (type == 'call_accept') {
      if (!_isCurrentCall(messageCallId)) return;
      await _handleAccepted();
      return;
    }

    if (type == 'call_cancelled') {
      if (!_isCurrentCall(messageCallId)) return;
      final cancelledCallId = messageCallId!;

      onRemoteCallCancelled?.call(cancelledCallId);
      await _cleanupCall(reason: 'cancelled');
      return;
    }

    if (type == 'hangup' || type == 'call_reject') {
      if (!_isCurrentCall(messageCallId)) return;
      await _cleanupCall(
        reason: type == 'call_reject' ? 'rejected' : 'ended',
      );
      return;
    }
  }

  bool _isCurrentCall(String? callId) {
    return callId != null && callId.isNotEmpty && callId == currentCallId;
  }

  Future<bool> startCall({
    required String targetId,
  }) async {
    final myId = session.userId;
    if (myId == null || targetId == myId) return false;

    if (currentCallId != null || inCall) return false;

    remoteUserId = targetId;
    currentCallId = const Uuid().v4();
    state = CallState.connecting;
    caller = true;
    inCall = false;
    remoteOnline = null;
    onRemoteAvailabilityChanged?.call(false);
    await session.markCallActive(currentCallId!);
    _pendingIceCandidates.clear();

    _callStartCompleter = Completer<bool>();
    session.socket.send({
      'type': 'call',
      'call_id': currentCallId,
      'target_id': targetId,
      'caller_name': session.displayName ?? 'Hesam',
      'from_id': myId,
    });

    // The server accepts the call immediately. Open the caller screen
    // without waiting for the target WebSocket/FCM path.
    // target_online only describes whether the target has a live socket.
    await _startRinging();
    return true;
  }

  Future<void> acceptCall({
    required String callerId,
    String? callId,
  }) async {
    final acceptedCallId = callId ?? currentCallId;
    if (acceptedCallId == null ||
        await session.isCallEnded(acceptedCallId) ||
        (currentCallId != null && currentCallId != acceptedCallId)) {
      return;
    }

    remoteUserId = callerId;
    currentCallId = callId ?? currentCallId;
    await session.markCallActive(currentCallId!);
    state = CallState.accepted;
    caller = false;
    inCall = false;
    _pendingIceCandidates.clear();

    session.socket.send({
      'type': 'call_accept',
      'call_id': currentCallId,
      'target_id': callerId,
    });

    try {
      await _connectLiveKit(currentCallId!);
    } catch (e) {
      print('[CN CALL][LIVEKIT] accept connect error: $e');
      await _cleanupCall(
        reason: 'failed',
        sendSignal: true,
        signalType: 'hangup',
      );
    }

    final activeCallId = currentCallId;
    if (activeCallId != null) {
      _startNegotiationTimeout(activeCallId);
      _startConnectionTimeout(activeCallId);
      state = CallState.connecting;
    }
  }

  Future<void> _handleAccepted() async {
    if (!caller) return;

    await _stopRinging();

    final acceptedCallId = currentCallId;
    if (acceptedCallId == null || acceptedCallId.isEmpty) return;

    state = CallState.connecting;

    try {
      await _connectLiveKit(acceptedCallId);
    } catch (e) {
      print('[CN CALL][LIVEKIT] caller connect error: $e');
      await _cleanupCall(
        reason: 'failed',
        sendSignal: true,
        signalType: 'hangup',
      );
    }
  }

  Future<void> rejectCall({
    required String callerId,
    String? callId,
  }) async {
    await _cleanupCall(
      reason: 'rejected',
      sendSignal: true,
      signalType: 'call_reject',
    );
  }

  Future<void> hangup({
    bool sendSignal = true,
  }) async {
    final shouldCancel = caller && !inCall;
    await _cleanupCall(
      reason: shouldCancel ? 'cancelled' : 'ended',
      sendSignal: sendSignal,
      signalType: shouldCancel ? 'call_cancelled' : 'hangup',
    );
  }

  Future<void> endForSession({bool sendSignal = true}) {
    return _cleanupCall(
      reason: 'ended',
      sendSignal: sendSignal,
      signalType: 'hangup',
    );
  }

  Future<void> _cleanupCall({
    required String reason,
    bool sendSignal = false,
    String? signalType,
  }) async {
    if (_hangingUp) return;

    _hangingUp = true;
    final callId = currentCallId;
    final target = remoteUserId;

    try {
      _callStartCompleter?.complete(false);
      _callStartCompleter = null;
      _callStartExpiresAt = null;
      _cancelCallTimeouts();
      await _stopRinging();

      if (sendSignal &&
          callId != null &&
          target != null &&
          session.loggedIn &&
          session.socket.connected) {
        session.socket.send({
          'type': signalType ?? 'hangup',
          'call_id': callId,
          'target_id': target,
        });
      }

      await livekit.disconnect();

      if (callId != null && callId.isNotEmpty) {
        await CallKitService.instance.forceEndCall(callId);
      }

      await session.markCallEnded(callId);
      await session.clearPendingIncomingCall(callId);
      await session.clearPendingCallKitAction(callId);

      _pendingIceCandidates.clear();
        remoteUserId = null;
      currentCallId = null;
      remoteOnline = null;
      inCall = false;
      caller = false;
      state = switch (reason) {
        'cancelled' => CallState.cancelled,
        'rejected' => CallState.rejected,
        'timeout' => CallState.timeout,
        'failed' => CallState.ended,
        _ => CallState.ended,
      };

      if (callId != null) onDisconnected?.call();
    } finally {
      _hangingUp = false;
    }
  }

  Future<void> mute(bool value) {
    return livekit.mute(value);
  }

  Future<void> setSpeaker(bool value) {
    return livekit.setSpeaker(value);
  }

  Future<void> dispose() async {
    await _cleanupCall(reason: 'ended', sendSignal: true);
    await _subscription?.cancel();
    _subscription = null;
    _started = false;

    await livekit.disconnect();
    await _ringPlayer.dispose();
  }

  Future<void> _connectLiveKit(String callId) async {
    print(
      '[CN CALL][LIVEKIT MANAGER] requesting token '
      'call_id=$callId',
    );

    final data = await LiveKitTokenService.getToken(
      callId: callId,
    );

    final url = data['url']?.toString();
    final token = data['token']?.toString();

    if (url == null || url.isEmpty) {
      throw Exception('LiveKit response missing url');
    }

    if (token == null || token.isEmpty) {
      throw Exception('LiveKit response missing token');
    }

    await livekit.connect(
      url: url,
      token: token,
    );
  }

}
