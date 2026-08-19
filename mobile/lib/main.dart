import 'package:flutter/material.dart';
import 'services/permissions.dart';
import 'screens/login.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await AppPermissions.requestAll();

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
