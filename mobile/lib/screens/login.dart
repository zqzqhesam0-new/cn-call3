import 'package:flutter/material.dart';
import '../services/auth.dart';
import '../services/socket_service.dart';
import 'home.dart';
import 'call.dart';
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


  void login() async {

    String result = await AuthService.login(
      idController.text,
      passController.text,
    );


    if (!mounted) return;


    if(result == "LOGIN_OK"){

      final socket = SocketService();

      socket.connect(
        idController.text,
      );


      socket.messages.listen((message){

        if(message.toString().startsWith("CALL_ACCEPTED:")){

          final userId =
              message.toString().replaceFirst(
                "CALL_ACCEPTED:",
                "",
              );

          if(!mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CallScreen(
                userId: userId,
              ),
            ),
          );

        }


        if(message.toString().startsWith("INCOMING_CALL:")){

          final callerId =
              message.toString().replaceFirst(
                "INCOMING_CALL:",
                "",
              );


          if(!mounted) return;


          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IncomingCallScreen(
                callerId: callerId,
                  socket: socket,
              ),
            ),
          );

        }

      });


      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(
            id: idController.text,
            socket: socket,
          ),
        ),
      );

    }else{

      setState(() {
        message = "بيانات الدخول غير صحيحة";
      });

    }
  }


  @override
  Widget build(BuildContext context){

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
                fontSize:40,
                fontWeight:FontWeight.bold,
              ),
            ),

            const SizedBox(height:30),


            TextField(
              controller:idController,
              decoration:const InputDecoration(
                labelText:"المعرف",
              ),
            ),


            TextField(
              controller:passController,
              obscureText:true,
              decoration:const InputDecoration(
                labelText:"كلمة المرور",
              ),
            ),


            const SizedBox(height:20),


            ElevatedButton(
              onPressed:login,
              child:const Text("دخول"),
            ),


            TextButton(
              onPressed:(){

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:(_)=>const RegisterPage(),
                  ),
                );

              },
              child:const Text("إنشاء حساب"),
            ),


            Text(
              message,
              style:const TextStyle(
                color:Colors.red,
              ),
            ),

          ],

        ),
      ),
    );
  }
}
