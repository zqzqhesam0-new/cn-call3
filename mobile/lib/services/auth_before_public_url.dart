import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {

  static const String baseUrl = "http://localhost:8080";


  static Future<bool> register(String id, String password) async {

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

    return response.statusCode == 200;
  }



  static Future<bool> login(String id, String password) async {

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
  }

}
