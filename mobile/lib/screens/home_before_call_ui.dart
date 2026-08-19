import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {

  final String id;

  const HomePage({
    super.key,
    required this.id,
  });


  @override
  Widget build(BuildContext context){

    return Scaffold(

      body: Center(

        child: Text(
          "مرحباً مستخدم $id\nجاهز للمكالمة الصوتية",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize:25,
          ),
        ),

      ),

    );

  }
}
