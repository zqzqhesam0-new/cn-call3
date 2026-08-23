import 'dart:async';

import 'call_session.dart';
import 'webrtc_call.dart';

class RtcCallManager {
  RtcCallManager._();

  static final RtcCallManager instance = RtcCallManager._();

  final CallSession session = CallSession.instance;
  final WebRtcCall rtc = WebRtcCall();

  StreamSubscription<Map<String, dynamic>>? _subscription;

  String? remoteUserId;
  bool inCall = false;
  bool caller = false;

  final List<Map<String, dynamic>> _pendingIceCandidates = [];
  bool _remoteDescriptionSet = false;

  Function()? onConnected;
  Function()? onDisconnected;
  Function(Map<String, dynamic> message)? onIncomingCall;

  bool _started = false;

  void startListening() {
    if (_started) return;
    _started = true;

    _subscription = session.socket.messages.listen(_handleMessage);

    rtc.onIceCandidate = (candidate) {
      final target = remoteUserId;
      if (target == null) return;

      session.socket.send({
        'type': 'ice_candidate',
        'target_id': target,
        'candidate': candidate.candidate,
        'sdp_mid': candidate.sdpMid,
        'sdp_mline_index': candidate.sdpMLineIndex,
      });
    };

    rtc.onConnected = () {
      inCall = true;
      onConnected?.call();
    };

    rtc.onDisconnected = () {
      inCall = false;
      onDisconnected?.call();
    };
  }

  Future<void> _handleMessage(Map<String, dynamic> message) async {
    final type = message['type']?.toString();

    if (type == 'call') {
      remoteUserId = message['from_id']?.toString();

      onIncomingCall?.call(message);
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

    if (type == 'hangup' || type == 'call_reject') {
      await hangup(sendSignal: false);
    }
  }

  Future<void> startCall({
    required String targetId,
  }) async {
    final myId = session.userId;
    if (myId == null) return;

    await hangup(sendSignal: false);

    remoteUserId = targetId;
    caller = true;
    inCall = false;
    _remoteDescriptionSet = false;
    _pendingIceCandidates.clear();

    await rtc.start();

    session.socket.send({
      'type': 'call',
      'target_id': targetId,
      'caller_name': session.displayName ?? 'Hesam',
      'from_id': myId,
    });
  }

  Future<void> acceptCall({
    required String callerId,
  }) async {
    remoteUserId = callerId;
    caller = false;
    inCall = false;
    _remoteDescriptionSet = false;
    _pendingIceCandidates.clear();

    await rtc.start();

    session.socket.send({
      'type': 'call_accept',
      'target_id': callerId,
    });
  }

  Future<void> _handleAccepted() async {
    if (!caller) return;

    final target = remoteUserId;
    if (target == null) return;

    final offer = await rtc.createOffer();

    session.socket.send({
      'type': 'offer',
      'target_id': target,
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

    if (!rtc.active) {
      await rtc.start();
    }

    await rtc.setRemoteDescription(sdp, type);

    _remoteDescriptionSet = true;

    await _flushPendingIceCandidates();

    final answer = await rtc.createAnswer();

    session.socket.send({
      'type': 'answer',
      'target_id': fromId,
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
  }) async {
    session.socket.send({
      'type': 'call_reject',
      'target_id': callerId,
    });

    await hangup(sendSignal: false);
  }

  Future<void> hangup({
    bool sendSignal = true,
  }) async {
    final target = remoteUserId;

    if (sendSignal && target != null) {
      session.socket.send({
        'type': 'hangup',
        'target_id': target,
      });
    }

    await rtc.close();

    _pendingIceCandidates.clear();
    _remoteDescriptionSet = false;

    remoteUserId = null;
    inCall = false;
    caller = false;
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
