// ignore_for_file: avoid_print

import 'package:livekit_client/livekit_client.dart';

class LiveKitCall {
  Room? _room;

  Function()? onConnected;
  Function()? onDisconnected;

  Room? get room => _room;

  Future<void> connect({
    required String url,
    required String token,
  }) async {
    _room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: false,
        dynacast: false,
      ),
    );

    _room!.events.listen((event) async {
      if (event is RoomConnectedEvent) {
        print('[CN CALL][LIVEKIT] CONNECTED');
        onConnected?.call();
      }

      if (event is RoomDisconnectedEvent) {
        print('[CN CALL][LIVEKIT] DISCONNECTED');
        onDisconnected?.call();
      }

      if (event is TrackSubscribedEvent) {
        print(
          '[CN CALL][LIVEKIT] TRACK SUBSCRIBED: ${event.track.kind}',
        );

        if (event.track is RemoteAudioTrack) {
          final audioTrack = event.track as RemoteAudioTrack;
          await audioTrack.start();
          print('[CN CALL][LIVEKIT] REMOTE AUDIO STARTED');
        }
      }
    });

    await _room!.connect(url, token);

    // Default audio route: phone earpiece, not speakerphone.
    await AudioManager.instance.setSpeakerOutputPreferred(false);

    await _room!.localParticipant?.setMicrophoneEnabled(true);
  }

  Future<void> setSpeaker(bool value) async {
    final room = _room;
    if (room == null) return;

    await AudioManager.instance.setSpeakerOutputPreferred(value);

    print(
      '[CN CALL][LIVEKIT] speaker '
      '${value ? 'on' : 'off'}',
    );
  }

  Future<void> mute(bool value) async {
    final participant = _room?.localParticipant;
    if (participant == null) return;

    await participant.setMicrophoneEnabled(!value);

    print(
      '[CN CALL][LIVEKIT] microphone '
      '${value ? 'muted' : 'unmuted'}',
    );
  }

  Future<void> disconnect() async {
    await _room?.disconnect();
    await _room?.dispose();
    _room = null;

    print('[CN CALL][LIVEKIT] DISCONNECTED');
  }
}
