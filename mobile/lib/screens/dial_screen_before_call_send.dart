import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import 'call_screen.dart';


class DialScreen extends StatefulWidget {

  final String myId;
  final SocketService socket;

  const DialScreen({
    super.key,
    required this.myId,
    required this.socket,
  });


  @override
  State<DialScreen> createState() => _DialScreenState();

}


class _DialScreenState extends State<DialScreen> {

  final controller = TextEditingController();


  @override
  Widget build(BuildContext context){

    return Scaffold(

      backgroundColor: Colors.black,


      appBar: AppBar(

        backgroundColor: Colors.black,

        title: const Text(
          "اتصال بمستخدم",
        ),

      ),


      body: Padding(

        padding: const EdgeInsets.all(25),


        child: Column(

          children: [


            TextField(

              controller: controller,

              style: const TextStyle(
                color: Colors.white,
              ),


              decoration: const InputDecoration(

                labelText: "ID المستخدم",

                labelStyle: TextStyle(
                  color: Colors.white70,
                ),

                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.white30,
                  ),
                ),

              ),

            ),


            const SizedBox(height:30),



            ElevatedButton.icon(

              icon: const Icon(Icons.call),


              label: const Text(
                "اتصال",
              ),


              style: ElevatedButton.styleFrom(

                backgroundColor:
                    Colors.green,

                padding:
                    const EdgeInsets.symmetric(
                      horizontal:40,
                      vertical:15,
                    ),

              ),



              onPressed:(){


                Navigator.push(

                  context,

                  MaterialPageRoute(

                    builder: (_) => CallScreen(

                      userId:
                          controller.text,

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
