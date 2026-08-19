import 'package:flutter/material.dart';
import 'call_screen.dart';

class HomePage extends StatelessWidget {

  final String id;

  const HomePage({
    super.key,
    required this.id,
  });


  @override
  Widget build(BuildContext context){

    return Scaffold(

      backgroundColor: Colors.black,

      body: Center(

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            Text(
              "مرحباً مستخدم $id",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize:25,
              ),
            ),

            const SizedBox(height:20),

            const Text(
              "جاهز للمكالمة الصوتية",
              style: TextStyle(
                color: Colors.white70,
                fontSize:18,
              ),
            ),

            const SizedBox(height:40),

            ElevatedButton.icon(

              icon: const Icon(Icons.call),

              label: const Text(
                "بدء مكالمة",
                style: TextStyle(
                  fontSize:18,
                ),
              ),

              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(
                  horizontal:40,
                  vertical:15,
                ),
              ),

              onPressed: (){

                Navigator.push(

                  context,

                  MaterialPageRoute(

                    builder: (_) => CallScreen(
                      userId: id,
                    ),

                  ),

                );

              },

            )

          ],

        ),

      ),

    );

  }

}
