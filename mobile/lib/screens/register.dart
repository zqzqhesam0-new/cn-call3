import 'package:flutter/material.dart';
import '../services/auth.dart';
import '../services/socket_service.dart';
import 'home.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {

  final idController = TextEditingController();
  final passController = TextEditingController();

  String message = "";

  void createAccount() async {

    String result = await AuthService.register(
      idController.text,
      passController.text,
    );

    if (result == "REGISTER_OK") {

      if (!mounted) return;

        final socket = SocketService();

        socket.connect(
          idController.text,
        );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(
            id: idController.text,
              socket: socket,
          ),
        ),
      );

    } else {

      setState(() {
        message = result == "USER_EXISTS"
            ? "المستخدم موجود بالفعل"
            : "حدث خطأ في الاتصال";
      });

    }
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("إنشاء حساب"),
      ),

      body: Padding(

        padding: const EdgeInsets.all(30),

        child: Column(

          children: [

            TextField(
              controller: idController,
              decoration: const InputDecoration(
                labelText: "رقم المستخدم",
              ),
            ),

            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "كلمة السر",
              ),
            ),

            const SizedBox(height:30),

            ElevatedButton(
              onPressed: createAccount,
              child: const Text("إنشاء"),
            ),

            Text(message)

          ],
        ),
      ),
    );
  }
}
