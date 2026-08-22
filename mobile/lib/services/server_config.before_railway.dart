class ServerConfig {
  static const String host =
      'ubiquitous-acorn-x9wwxwr9x4rcvq57-8000.app.github.dev';

  static String get httpUrl {
    return 'https://$host';
  }

  static String websocketUrl(String userId) {
    return 'wss://$host/ws/$userId';
  }
}
