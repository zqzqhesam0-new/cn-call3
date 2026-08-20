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
  final nameController = TextEditingController();
  final passController = TextEditingController();

  String message = "";
  bool loading = false;

  Future<void> createAccount() async {
    final id = idController.text.trim();
    final name = nameController.text.trim();
    final password = passController.text;

    if (id.isEmpty || name.isEmpty || password.isEmpty) {
      setState(() {
        message = "أكمل جميع البيانات";
      });
      return;
    }

    setState(() {
      loading = true;
      message = "";
    });

    final result = await AuthService.register(
      id,
      password,
      displayName: name,
    );

    if (!mounted) return;

    setState(() {
      loading = false;
    });

    if (result == "REGISTER_OK") {
      final socket = SocketService();

      socket.connect(id);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(
            id: id,
            displayName: name,
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
  void dispose() {
    idController.dispose();
    nameController.dispose();
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("إنشاء حساب"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: "اسم المستخدم",
                hintText: "الاسم الذي سيظهر للمتصلين",
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: idController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: "رقم المستخدم",
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "كلمة المرور",
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : createAccount,
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text("إنشاء الحساب"),
              ),
            ),

            const SizedBox(height: 15),

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
