import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'server_config.dart';

class CallSocket {
  WebSocketChannel? _channel;
  String? _userId;
  Timer? _reconnectTimer;
  bool _connecting = false;
  int _reconnectAttempt = 0;

  final List<Map<String, dynamic>> _pendingMessages = [];

  static const _queuedTypes = {
    'call_accept',
    'call_reject',
    'call_cancelled',
  };

  bool get connected => _channel != null;

  final StreamController<Map<String, dynamic>> _messages =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messages.stream;

  Future<void> connect(String userId) async {
    if (_channel != null) return;
    _userId = userId;
    if (_channel != null || _connecting) return;

    _connecting = true;

    final channel = WebSocketChannel.connect(
      Uri.parse(ServerConfig.websocketUrl(userId)),
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

              print('SOCKET RECEIVE: $parsed');

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
          _scheduleReconnect();
        },
        onError: (error, stackTrace) {
          print('SOCKET ERROR: $error');

          if (identical(_channel, channel)) {
            _channel = null;
          }
          _scheduleReconnect();
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
      _scheduleReconnect();

      rethrow;
    }
  }

  void _scheduleReconnect() {
    final userId = _userId;
    if (userId == null || userId.isEmpty || _reconnectTimer != null) return;

    final delaySeconds = 1 << (_reconnectAttempt.clamp(0, 5));
    _reconnectAttempt++;

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      _reconnectTimer = null;
      try {
        await connect(userId);
      } catch (_) {
        _scheduleReconnect();
      }
    });
  }

  void _flushPendingMessages() {
    final pending = List<Map<String, dynamic>>.from(_pendingMessages);
    _pendingMessages.clear();
    for (final message in pending) {
      _channel?.sink.add(jsonEncode(message));
    }
  }
  void send(Map<String, dynamic> data) {
    final channel = _channel;

    print('SOCKET SEND: $data');

    if (channel == null) {
      print('SOCKET NOT CONNECTED');
      if (_queuedTypes.contains(data['type'])) {
        _pendingMessages.add(Map<String, dynamic>.from(data));
        final userId = _userId;
        if (userId != null) {
          _scheduleReconnect();
        }
      }
      return;
    }

    channel.sink.add(jsonEncode(data));
  }

  void disconnect() {
    _userId = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    await _messages.close();

    _userId = null;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
