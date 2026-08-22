import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'server_config.dart';

class CallSocket {
  WebSocketChannel? _channel;

  bool get connected => _channel != null;

  final StreamController<Map<String, dynamic>> _messages =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messages.stream;

  void connect(String userId) {
    if (_channel != null) return;

    final channel = WebSocketChannel.connect(
      Uri.parse(ServerConfig.websocketUrl(userId)),
    );

    _channel = channel;

    channel.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message);

          if (data is Map) {
            _messages.add(
              Map<String, dynamic>.from(data),
            );
          }
        } catch (_) {
          // تجاهل الرسائل غير الصالحة
        }
      },
      onDone: () {
        if (identical(_channel, channel)) {
          _channel = null;
        }
      },
      onError: (error, stackTrace) {
        if (identical(_channel, channel)) {
          _channel = null;
        }
      },
    );
  }

  void send(Map<String, dynamic> data) {
    final channel = _channel;

    if (channel == null) return;

    channel.sink.add(jsonEncode(data));
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    await _messages.close();
    _channel?.sink.close();
    _channel = null;
  }
}
