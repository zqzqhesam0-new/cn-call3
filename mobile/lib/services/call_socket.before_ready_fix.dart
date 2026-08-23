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

  Future<void> connect(String userId) async {
    if (_channel != null) return;

    final channel = WebSocketChannel.connect(
      Uri.parse(ServerConfig.websocketUrl(userId)),
    );

    _channel = channel;

    try {
      await channel.ready;

      if (!identical(_channel, channel)) {
        await channel.sink.close();
        return;
      }

      print('SOCKET CONNECTED: user=$userId');

      channel.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);

            if (data is Map) {
              _messages.add(
                Map<String, dynamic>.from(data),
              );
            }
          } catch (e) {
            print('SOCKET MESSAGE ERROR: $e');
          }
        },
        onDone: () {
          if (identical(_channel, channel)) {
            _channel = null;
          }

          print('SOCKET CLOSED: user=$userId');
        },
        onError: (error, stackTrace) {
          if (identical(_channel, channel)) {
            _channel = null;
          }

          print('SOCKET ERROR: $error');
        },
      );
    } catch (e) {
      if (identical(_channel, channel)) {
        _channel = null;
      }

      print('SOCKET CONNECT ERROR: $e');

      try {
        await channel.sink.close();
      } catch (_) {}
    }
  }

  void send(Map<String, dynamic> data) {
    final channel = _channel;

    print('SOCKET SEND: $data');

    if (channel == null) {
      print('SOCKET NOT CONNECTED');
      return;
    }

    channel.sink.add(jsonEncode(data));
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    await _messages.close();

    try {
      await _channel?.sink.close();
    } catch (_) {}

    _channel = null;
  }
}
