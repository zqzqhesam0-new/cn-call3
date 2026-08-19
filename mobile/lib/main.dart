
import 'package:flutter/material.dart';

void main() {
  runApp(const CNCallApp());
}

class CNCallApp extends StatelessWidget {
  const CNCallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CN CALL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              const Text(
                'CN CALL',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'مكالمة صوتية بدون رقم هاتف',
                style: TextStyle(fontSize: 18),
              ),

              const SizedBox(height: 40),

              const TextField(
                decoration: InputDecoration(
                  labelText: 'اسم المستخدم ID',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              const TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'كلمة السر',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: () {},
                child: const Text('دخول'),
              ),

              ElevatedButton(
                onPressed: () {},
                child: const Text('إنشاء حساب'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
