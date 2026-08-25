import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:uuid/uuid.dart';

import 'call_session.dart';
import 'webrtc_call.dart';

enum CallState {
  incoming,
  accepted,
  rejected,
  cancelled,
  connecting,
  connected,
  ended,
  timeout,
}

class RtcCallManager {
  RtcCallManager._();

  static final RtcCallManager instance = RtcCallManager._();

  final CallSession session = CallSession.instance;
  final WebRtcCall rtc = WebRtcCall();

  final AudioPlayer _ringPlayer = AudioPlayer();
  bool _ringing = false;
  Timer? _ringTimeoutTimer;

  StreamSubscription<Map<String, dynamic>>? _subscription;

  String? remoteUserId;
  String? currentCallId;
  CallState? state;
  bool inCall = false;
  bool caller = false;

  final List<Map<String, dynamic>> _pendingIceCandidates = [];
  bool _remoteDescriptionSet = false;

  Function()? onConnected;
  Function()? onDisconnected;
  Function(Map<String, dynamic> message)? onIncomingCall;
  Function(String callId)? onRemoteCallCancelled;

  bool _started = false;
  bool _hangingUp = false;

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

  Future<void> _handleRingTimeout() async {
    if (!caller || inCall || currentCallId == null) return;

    print('[CN CALL][RING] timeout reached');

    await hangup(sendSignal: true);
    state = CallState.timeout;
  }

  void startListening() {
    if (_started) return;
    _started = true;

    _subscription = session.socket.messages.listen(_handleMessage);

    rtc.onIceCandidate = (candidate) {
      final target = remoteUserId;
      if (target == null) return;

      session.socket.send({
        'type': 'ice_candidate',
        'call_id': currentCallId,
        'target_id': target,
        'from_id': session.userId,
        'candidate': candidate.candidate,
        'sdp_mid': candidate.sdpMid,
        'sdp_mline_index': candidate.sdpMLineIndex,
      });
    };

    rtc.onConnected = () {
      inCall = true;
      state = CallState.connected;
      onConnected?.call();
    };

    rtc.onDisconnected = () {
      if (_hangingUp) return;

      inCall = false;
      remoteUserId = null;
      caller = false;
      _remoteDescriptionSet = false;
      _pendingIceCandidates.clear();

      onDisconnected?.call();
    };
  }

  Future<void> _handleMessage(Map<String, dynamic> message) async {
    final type = message['type']?.toString();

    if (type == 'call') {
      currentCallId = message['call_id']?.toString();
      state = CallState.incoming;
      remoteUserId = message['from_id']?.toString();

      onIncomingCall?.call(message);
      return;
    }

    if (type == 'call_started') {
      currentCallId = message['call_id']?.toString();

      final expiresAtRaw = message['ring_expires_at'];
      final expiresAt = expiresAtRaw is int
          ? expiresAtRaw
          : int.tryParse(expiresAtRaw?.toString() ?? '');

      if (caller && _ringing && expiresAt != null) {
        await _startRinging(expiresAt: expiresAt);
      }

      return;
    }

    if (type == 'call_accept') {
      await _handleAccepted();
      return;
    }

    if (type == 'offer') {
      await _handleOffer(message);
      return;
    }

    if (type == 'answer') {
      await _handleAnswer(message);
      return;
    }

    if (type == 'ice_candidate') {
      await _handleIceCandidate(message);
      return;
    }

    if (type == 'call_cancelled') {
      final cancelledCallId =
          message['call_id']?.toString() ?? currentCallId;

      if (cancelledCallId != null && cancelledCallId.isNotEmpty) {
        onRemoteCallCancelled?.call(cancelledCallId);
      }

      await hangup(sendSignal: false);
      return;
    }

    if (type == 'hangup' || type == 'call_reject') {
      await hangup(sendSignal: false);
      state = type == 'call_reject' ? CallState.rejected : CallState.ended;
      return;
    }
  }

  Future<void> startCall({
    required String targetId,
  }) async {
    final myId = session.userId;
    if (myId == null) return;

    await hangup(sendSignal: false);

    remoteUserId = targetId;
    currentCallId = const Uuid().v4();
    state = CallState.connecting;
    caller = true;
    inCall = false;
    _remoteDescriptionSet = false;
    _pendingIceCandidates.clear();

    await rtc.start();

    session.socket.send({
      'type': 'call',
      'call_id': currentCallId,
      'target_id': targetId,
      'caller_name': session.displayName ?? 'Hesam',
      'from_id': myId,
    });

    await _startRinging();
  }

  Future<void> acceptCall({
    required String callerId,
    String? callId,
  }) async {
    remoteUserId = callerId;
    currentCallId = callId ?? currentCallId;
    state = CallState.accepted;
    caller = false;
    inCall = false;
    _remoteDescriptionSet = false;
    _pendingIceCandidates.clear();

    await rtc.start();

    session.socket.send({
      'type': 'call_accept',
      'call_id': currentCallId,
      'target_id': callerId,
    });
  }

  Future<void> _handleAccepted() async {
    if (!caller) return;

    await _stopRinging();

    final target = remoteUserId;
    if (target == null) return;

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
    session.socket.send({
      'type': 'call_reject',
      'call_id': callId ?? currentCallId,
      'target_id': callerId,
    });

    await hangup(sendSignal: false);
    state = CallState.rejected;
  }

  Future<void> hangup({
    bool sendSignal = true,
  }) async {
    if (_hangingUp) return;

    _hangingUp = true;
    await _stopRinging();

    final target = remoteUserId;
    final callId = currentCallId;
    final shouldCancel = caller && !inCall && callId != null;

    if (sendSignal && target != null) {
      session.socket.send({
        'type': shouldCancel ? 'call_cancelled' : 'hangup',
        'call_id': callId,
        'target_id': target,
      });
    }

    await rtc.close();

    _pendingIceCandidates.clear();
    _remoteDescriptionSet = false;

    remoteUserId = null;
    currentCallId = null;
    state = shouldCancel ? CallState.cancelled : CallState.ended;
    inCall = false;
    caller = false;

    onDisconnected?.call();

    _hangingUp = false;
  }

  Future<void> mute(bool value) {
    return rtc.mute(value);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;

    await rtc.close();
  }
}
