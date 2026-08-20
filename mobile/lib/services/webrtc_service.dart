import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'socket_service.dart';

class WebRTCService {
  final SocketService socket;
  final String target;
  final VoidCallback? onConnected;

  RTCPeerConnection? peer;
  MediaStream? localStream;

  bool closed = false;
  bool connectedReported = false;
  bool remoteDescriptionSet = false;

  final List<String> pendingIce = [];

  WebRTCService(
    this.socket,
    this.target, {
    this.onConnected,
  });

  Future<void> initialize() async {
    if (closed) return;

    try {
      localStream = await navigator.mediaDevices.getUserMedia({
        "audio": true,
        "video": false,
      });

      if (closed) {
        await localStream?.dispose();
        localStream = null;
        return;
      }
    } catch (e) {
      debugPrint("MIC ERROR: $e");
    }

    if (closed) return;

    peer = await createPeerConnection({
      "iceServers": [
        {
          "urls": "stun:stun.l.google.com:19302",
        },
      ],
    });

    if (closed) {
      await peer?.close();
      peer = null;
      return;
    }

    if (localStream != null) {
      for (final track in localStream!.getTracks()) {
        await peer!.addTrack(
          track,
          localStream!,
        );
      }
    }

    peer!.onIceCandidate = (candidate) {
      if (closed) return;

      final value = candidate.candidate;

      if (value != null && value.isNotEmpty) {
        socket.sendIceCandidate(
          target,
          value,
        );
      }
    };

    peer!.onTrack = (event) {
      debugPrint(
        "REMOTE TRACK: ${event.track.kind} ${event.track.id}",
      );
    };

    peer!.onIceConnectionState = (state) {
      debugPrint("ICE STATE: $state");

      if (state ==
              RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state ==
              RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _reportConnected();
      }
    };

    peer!.onConnectionState = (state) {
      debugPrint("PEER STATE: $state");

      if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _reportConnected();
      }
    };
  }

  void _reportConnected() {
    if (closed || connectedReported) return;

    connectedReported = true;

    debugPrint("WEBRTC CONNECTED");

    onConnected?.call();
  }

  Future<void> createOffer() async {
    if (closed || peer == null) return;

    final offer = await peer!.createOffer();

    if (closed) return;

    await peer!.setLocalDescription(offer);

    if (closed) return;

    if (offer.sdp != null) {
      socket.sendOffer(
        target,
        offer.sdp!,
      );
    }
  }

  Future<void> createAnswer(String offer) async {
    if (closed || peer == null) return;

    await peer!.setRemoteDescription(
      RTCSessionDescription(
        offer,
        "offer",
      ),
    );

    if (closed) return;

    remoteDescriptionSet = true;

    await _flushPendingIce();

    if (closed) return;

    final answer = await peer!.createAnswer();

    if (closed) return;

    await peer!.setLocalDescription(answer);

    if (closed) return;

    if (answer.sdp != null) {
      socket.sendAnswer(
        target,
        answer.sdp!,
      );
    }
  }

  Future<void> setAnswer(String answer) async {
    if (closed || peer == null) return;

    await peer!.setRemoteDescription(
      RTCSessionDescription(
        answer,
        "answer",
      ),
    );

    if (closed) return;

    remoteDescriptionSet = true;

    await _flushPendingIce();
  }

  Future<void> addIce(String ice) async {
    if (closed || peer == null) return;

    if (ice.trim().isEmpty) return;

    if (!remoteDescriptionSet) {
      pendingIce.add(ice);
      debugPrint("ICE QUEUED");
      return;
    }

    await peer!.addCandidate(
      RTCIceCandidate(
        ice,
        "",
        0,
      ),
    );
  }

  Future<void> _flushPendingIce() async {
    if (closed || peer == null || !remoteDescriptionSet) {
      return;
    }

    if (pendingIce.isEmpty) return;

    final candidates = List<String>.from(pendingIce);
    pendingIce.clear();

    for (final ice in candidates) {
      if (closed || peer == null) return;

      try {
        await peer!.addCandidate(
          RTCIceCandidate(
            ice,
            "",
            0,
          ),
        );
      } catch (e) {
        debugPrint("ICE ADD ERROR: $e");
      }
    }

    debugPrint(
      "ICE FLUSHED: ${candidates.length}",
    );
  }

  Future<void> close() async {
    if (closed) return;

    closed = true;

    pendingIce.clear();

    try {
      for (final track
          in localStream?.getTracks() ?? <MediaStreamTrack>[]) {
        try {
          await track.stop();
        } catch (_) {}
      }
    } catch (_) {}

    try {
      await localStream?.dispose();
    } catch (_) {}

    localStream = null;

    try {
      await peer?.close();
    } catch (_) {}

    peer = null;
  }
}
