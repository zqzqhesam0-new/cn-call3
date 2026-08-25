import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'server_config.dart';

class CallSocket {
  WebSocketChannel? _channel;
  String? _userId;
  String? _token;
  Timer? _reconnectTimer;
  bool _connecting = false;
  bool _reconnectEnabled = true;
  int _reconnectAttempt = 0;
  Future<void> Function()? onSessionInvalid;

  bool get connected => _channel != null;

  final StreamController<Map<String, dynamic>> _messages =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messages.stream;

  Future<void> connect(String userId, String token) async {
    if (_channel != null) return;
    _userId = userId;
    _token = token;
    _reconnectEnabled = true;
    if (_channel != null || _connecting) return;

    _connecting = true;

    final channel = WebSocketChannel.connect(
      Uri.parse('${ServerConfig.websocketUrl(userId)}?token=$token'),
    );

    try {
      await channel.ready;

      _channel = channel;
      _connecting = false;
      _reconnectAttempt = 0;

      print('SOCKET CONNECTED: ${ServerConfig.websocketUrl(userId)}');
      _flushPendingMessages();

      channel.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);

            if (data is Map) {
              final parsed = Map<String, dynamic>.from(data);

              if (parsed['type'] == 'session_invalid') {
                _handleSessionInvalid();
                return;
              }

              print(
                'SOCKET RECEIVE: type=${parsed['type']} '
                'call_id=${parsed['call_id']}',
              );

              _messages.add(parsed);
            }
          } catch (e) {
            print('SOCKET JSON ERROR: $e');
          }
        },
        onDone: () {
          print('SOCKET CLOSED');

          if (identical(_channel, channel)) {
            _channel = null;
          }
          if (_reconnectEnabled) _scheduleReconnect();
        },
        onError: (error, stackTrace) {
          print('SOCKET ERROR: $error');

          if (identical(_channel, channel)) {
            _channel = null;
          }
          if (_reconnectEnabled) _scheduleReconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      print('SOCKET CONNECT ERROR: $e');

      await channel.sink.close();

      if (identical(_channel, channel)) {
        _channel = null;
      }

      _connecting = false;
      if (_reconnectEnabled) _scheduleReconnect();

      rethrow;
    }
  }

  void _scheduleReconnect() {
    final userId = _userId;
    final token = _token;
    if (!_reconnectEnabled ||
      userId == null ||
        userId.isEmpty ||
        token == null ||
        token.isEmpty ||
        _reconnectTimer != null) {
      return;
    }

    final delaySeconds = 1 << (_reconnectAttempt.clamp(0, 5));
    _reconnectAttempt++;

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      _reconnectTimer = null;
      try {
        await connect(userId, token);
      } catch (_) {
        _scheduleReconnect();
      }
    });
  }

  void _flushPendingMessages() {
    // Control messages must not be replayed after reconnect.
  }
  void send(Map<String, dynamic> data) {
    final channel = _channel;

    print(
      'SOCKET SEND: type=${data['type']} call_id=${data['call_id']}',
    );

    if (channel == null) {
      print('SOCKET NOT CONNECTED');
      return;
    }

    channel.sink.add(jsonEncode(data));
  }

  void disconnect() {
    _reconnectEnabled = false;
    _userId = null;
    _token = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    _reconnectEnabled = false;
    await _messages.close();

    _userId = null;
    _token = null;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void _handleSessionInvalid() {
    _reconnectEnabled = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connecting = false;
    final channel = _channel;
    _channel = null;
    channel?.sink.close();
    onSessionInvalid?.call();
  }
}
