import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth.dart';
import '../services/socket_service.dart';
import 'home.dart';
import 'register.dart';
import 'incoming_call.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final idController = TextEditingController();
  final passController = TextEditingController();

  String message = "";
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    final prefs = await SharedPreferences.getInstance();

    final savedId = prefs.getString("cn_call_id");
    final savedPassword = prefs.getString("cn_call_password");

    if (!mounted) return;

    if (savedId != null &&
        savedId.isNotEmpty &&
        savedPassword != null &&
        savedPassword.isNotEmpty) {
      final savedDisplayName =
          prefs.getString("cn_call_display_name") ?? savedId;

      _openHome(
        savedId,
        savedPassword,
        savedDisplayName,
      );
      return;
    }

    setState(() {
      loading = false;
    });
  }

  Future<void> login() async {
    final id = idController.text.trim();
    final password = passController.text;

    if (id.isEmpty || password.isEmpty) {
      setState(() {
        message = "أدخل المعرف وكلمة المرور";
      });
      return;
    }

    setState(() {
      loading = true;
      message = "";
    });

    final result = await AuthService.login(
      id,
      password,
    );

    if (!mounted) return;

    if (result.startsWith("LOGIN_OK")) {
      final prefs = await SharedPreferences.getInstance();

      final displayName = result.startsWith("LOGIN_OK:")
          ? result.substring("LOGIN_OK:".length).trim()
          : id;

      await prefs.setString(
        "cn_call_id",
        id,
      );

      await prefs.setString(
        "cn_call_password",
        password,
      );

      await prefs.setString(
        "cn_call_display_name",
        displayName.isEmpty ? id : displayName,
      );

      if (!mounted) return;

      _openHome(
        id,
        password,
        displayName.isEmpty ? id : displayName,
      );
    } else {
      setState(() {
        loading = false;
        message = "بيانات الدخول غير صحيحة";
      });
    }
  }

  void _openHome(
    String id,
    String password,
    String displayName,
  ) {
    final socket = SocketService();

    socket.connect(id);

    socket.messages.listen((message) {
      final text = message.toString();

      debugPrint("GLOBAL SOCKET MESSAGE: $text");

      if (text.startsWith("INCOMING_CALL:")) {
        final parts = text.split(":");

        if (parts.length < 2) return;

        final callerId = parts[1];
        final callerName =
            parts.length >= 3
                ? parts.sublist(2).join(":")
                : callerId;

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IncomingCallScreen(
              callerId: callerId,
              callerName: callerName,
              socket: socket,
            ),
          ),
        );
      }
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomePage(
          id: id,
          displayName: displayName,
          socket: socket,
        ),
      ),
    );
  }

  @override
  void dispose() {
    idController.dispose();
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.blue,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "CN CALL",
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 30),

            TextField(
              controller: idController,
              style: const TextStyle(
                color: Colors.white,
              ),
              decoration: const InputDecoration(
                labelText: "المعرف",
              ),
            ),

            TextField(
              controller: passController,
              obscureText: true,
              style: const TextStyle(
                color: Colors.white,
              ),
              decoration: const InputDecoration(
                labelText: "كلمة المرور",
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: login,
              child: const Text("دخول"),
            ),

            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RegisterPage(),
                  ),
                );
              },
              child: const Text("إنشاء حساب"),
            ),

            Text(
              message,
              style: const TextStyle(
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
