import 'dart:convert';

import 'package:http/http.dart' as http;

import 'server_config.dart';

class AccountApi {
  static Uri _uri(String path) {
    return Uri.parse('${ServerConfig.httpUrl}$path');
  }

  static Future<Map<String, dynamic>> login({
    required String userId,
    required String password,
  }) async {
    try {
      final response = await http.post(
        _uri('/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }

      return {
        'success': false,
        'message': 'استجابة غير صالحة من السيرفر',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'تعذر الاتصال بالسيرفر',
      };
    }
  }

  static Future<Map<String, dynamic>> register({
    required String userId,
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        _uri('/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'username': username,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }

      return {
        'success': false,
        'message': 'استجابة غير صالحة من السيرفر',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'تعذر الاتصال بالسيرفر',
      };
    }
  }
}
