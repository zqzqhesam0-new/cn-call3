import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:uuid/uuid.dart';

import 'call_session.dart';
import 'webrtc_call.dart';

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
  final WebRtcCall rtc = WebRtcCall();

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
  bool _remoteDescriptionSet = false;

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

    rtc.onIceCandidate = (candidate) {
      final target = remoteUserId;
      final callId = currentCallId;
      if (target == null || callId == null || callId.isEmpty) return;

      session.socket.send({
        'type': 'ice_candidate',
        'call_id': callId,
        'target_id': target,
        'from_id': session.userId,
        'candidate': candidate.candidate,
        'sdp_mid': candidate.sdpMid,
        'sdp_mline_index': candidate.sdpMLineIndex,
      });
    };

    rtc.onConnected = () {
      final connectedCallId = currentCallId;
      final target = remoteUserId;

      _cancelCallTimeouts();
      inCall = true;
      state = CallState.connected;

      if (connectedCallId != null &&
          connectedCallId.isNotEmpty &&
          target != null &&
          target.isNotEmpty) {
        session.socket.send({
          'type': 'connected',
          'call_id': connectedCallId,
          'target_id': target,
          'from_id': session.userId,
        });
      }

      onConnected?.call();
    };

    rtc.onDisconnected = () {
      if (_hangingUp) return;

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
      state = remoteOnline! ? CallState.ringing : CallState.offline;
      final expiresAtRaw = message['ring_expires_at'];
      _callStartExpiresAt = expiresAtRaw is int
          ? expiresAtRaw
          : int.tryParse(expiresAtRaw?.toString() ?? '');
      _callStartCompleter?.complete(remoteOnline!);
      _callStartCompleter = null;

      return;
    }

    if (type == 'call_accept') {
      if (!_isCurrentCall(messageCallId)) return;
      await _handleAccepted();
      return;
    }

    if (type == 'offer') {
      if (!_isCurrentCall(messageCallId)) return;
      await _handleOffer(message);
      return;
    }

    if (type == 'answer') {
      if (!_isCurrentCall(messageCallId)) return;
      await _handleAnswer(message);
      return;
    }

    if (type == 'ice_candidate') {
      if (!_isCurrentCall(messageCallId)) return;
      await _handleIceCandidate(message);
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
    _remoteDescriptionSet = false;
    _pendingIceCandidates.clear();

    _callStartCompleter = Completer<bool>();
    session.socket.send({
      'type': 'call',
      'call_id': currentCallId,
      'target_id': targetId,
      'caller_name': session.displayName ?? 'Hesam',
      'from_id': myId,
    });

    final targetAvailable = await _callStartCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => false,
    );
    _callStartCompleter = null;

    if (!targetAvailable) {
      _callStartExpiresAt = null;
      _callStartCompleter = null;
      await hangup(sendSignal: true);
      state = CallState.offline;
      return false;
    }

    final expiresAt = _callStartExpiresAt;
    _callStartExpiresAt = null;
    await _startRinging(expiresAt: expiresAt);
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
    _remoteDescriptionSet = false;
    _pendingIceCandidates.clear();

    session.socket.send({
      'type': 'call_accept',
      'call_id': currentCallId,
      'target_id': callerId,
    });

    await rtc.start();
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

    final target = remoteUserId;
    if (target == null) return;

    await rtc.start();
    final acceptedCallId = currentCallId;
    if (acceptedCallId != null) {
      _startNegotiationTimeout(acceptedCallId);
      _startConnectionTimeout(acceptedCallId);
      state = CallState.connecting;
    }
    final offer = await rtc.createOffer();

    session.socket.send({
      'type': 'offer',
      'call_id': currentCallId,
      'target_id': target,
      'from_id': session.userId,
      'sdp': offer.sdp,
      'sdp_type': offer.type,
    });
  }

  Future<void> _handleOffer(Map<String, dynamic> message) async {
    final fromId = message['from_id']?.toString();
    final sdp = message['sdp']?.toString();
    final type = message['sdp_type']?.toString();

    if (fromId == null || sdp == null || type == null) return;

    remoteUserId = fromId;
    state = CallState.connecting;

    if (!rtc.active) {
      await rtc.start();
    }

    await rtc.setRemoteDescription(sdp, type);

    _remoteDescriptionSet = true;

    await _flushPendingIceCandidates();

    final answer = await rtc.createAnswer();

    session.socket.send({
      'type': 'answer',
      'call_id': currentCallId,
      'target_id': fromId,
      'from_id': session.userId,
      'sdp': answer.sdp,
      'sdp_type': answer.type,
    });
  }

  Future<void> _handleAnswer(Map<String, dynamic> message) async {
    final sdp = message['sdp']?.toString();
    final type = message['sdp_type']?.toString();

    if (sdp == null || type == null) return;

    await rtc.setRemoteDescription(sdp, type);

    _remoteDescriptionSet = true;

    await _flushPendingIceCandidates();
  }

  Future<void> _handleIceCandidate(
    Map<String, dynamic> message,
  ) async {
    final candidate = message['candidate']?.toString();

    if (candidate == null || candidate.isEmpty) return;

    if (!_remoteDescriptionSet) {
      _pendingIceCandidates.add(message);
      return;
    }

    await rtc.addCandidate(
      candidate: candidate,
      sdpMid: message['sdp_mid']?.toString(),
      sdpMLineIndex: _toInt(message['sdp_mline_index']),
    );
  }

  Future<void> _flushPendingIceCandidates() async {
    if (!_remoteDescriptionSet) return;

    final pending = List<Map<String, dynamic>>.from(
      _pendingIceCandidates,
    );

    _pendingIceCandidates.clear();

    for (final message in pending) {
      final candidate = message['candidate']?.toString();

      if (candidate == null || candidate.isEmpty) continue;

      await rtc.addCandidate(
        candidate: candidate,
        sdpMid: message['sdp_mid']?.toString(),
        sdpMLineIndex: _toInt(message['sdp_mline_index']),
      );
    }
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
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

      await rtc.close();
      await session.markCallEnded(callId);
      await session.clearPendingIncomingCall(callId);
      await session.clearPendingCallKitAction(callId);

      _pendingIceCandidates.clear();
      _remoteDescriptionSet = false;
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
    return rtc.mute(value);
  }

  Future<void> dispose() async {
    await _cleanupCall(reason: 'ended', sendSignal: true);
    await _subscription?.cancel();
    _subscription = null;
    _started = false;

    await rtc.dispose();
    await _ringPlayer.dispose();
  }
}
