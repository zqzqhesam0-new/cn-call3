import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

class SocketService {
  WebSocketChannel? channel;

  final StreamController<String> _messagesController =
      StreamController<String>.broadcast();

  StreamSubscription? _socketSubscription;

  bool connected = false;

  void connect(String id) {
    if (connected) return;

    channel = WebSocketChannel.connect(
      Uri.parse(
        "wss://ubiquitous-acorn-x9wwxwr9x4rcvq57-8080.app.github.dev/ws/$id",
      ),
    );

    connected = true;

    _socketSubscription = channel!.stream.listen(
      (message) {
        if (!_messagesController.isClosed) {
          _messagesController.add(message.toString());
        }
      },
      onError: (error) {
        if (!_messagesController.isClosed) {
          _messagesController.addError(error);
        }
      },
      onDone: () {
        connected = false;
      },
      cancelOnError: false,
    );
  }

  void callUser(String target) {
    channel?.sink.add("CALL_REQUEST:$target");
  }

  void acceptCall(String callerId) {
    channel?.sink.add("ACCEPT_CALL:$callerId");
  }

  void rejectCall(String callerId) {
    channel?.sink.add("REJECT_CALL:$callerId");
  }

  void endCall(String target) {
    channel?.sink.add("END_CALL:$target");
  }

  void sendOffer(String target, String offer) {
    channel?.sink.add("OFFER:$target:$offer");
  }

  void sendAnswer(String target, String answer) {
    channel?.sink.add("ANSWER:$target:$answer");
  }

  void sendIceCandidate(String target, String candidate) {
    channel?.sink.add("ICE:$target:$candidate");
  }

  Stream<String> get messages => _messagesController.stream;

  Future<void> close() async {
    connected = false;

    await _socketSubscription?.cancel();
    _socketSubscription = null;

    try {
      await channel?.sink.close();
    } catch (_) {}

    channel = null;
  }
}
