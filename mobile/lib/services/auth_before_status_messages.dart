import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {

  static const String baseUrl =
      "https://ubiquitous-acorn-x9wwxwr9x4rcvq57-8080.app.github.dev";


  static Future<bool> register(String id, String password) async {

    try {

      final response = await http.post(
        Uri.parse("$baseUrl/register"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "id": id,
          "password": password,
        }),
      );

      return response.body == "REGISTER_OK";

    } catch (e) {

      return false;

    }
  }


  static Future<bool> login(String id, String password) async {

    try {

      final response = await http.post(
        Uri.parse("$baseUrl/login"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "id": id,
          "password": password,
        }),
      );

      return response.body == "LOGIN_OK";

    } catch (e) {

      return false;

    }
  }

}
