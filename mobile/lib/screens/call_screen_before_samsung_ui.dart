import 'package:flutter/material.dart';
import '../widgets/call_button.dart';


class CallScreen extends StatelessWidget {

  final String userId;

  const CallScreen({
    super.key,
    required this.userId,
  });


  @override
  Widget build(BuildContext context){

    return Scaffold(

      backgroundColor: Colors.black,

      body: SafeArea(

        child: Column(

          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [

            const SizedBox(),

            Column(
              children: [

                CircleAvatar(
                  radius:70,
                  backgroundColor: Colors.grey[800],
                  child: const Icon(
                    Icons.person,
                    size:80,
                    color:Colors.white,
                  ),
                ),

                const SizedBox(height:25),

                Text(
                  userId,
                  style: const TextStyle(
                    color:Colors.white,
                    fontSize:28,
                    fontWeight:FontWeight.bold,
                  ),
                ),

                const SizedBox(height:10),

                const Text(
                  "جاري الاتصال...",
                  style: TextStyle(
                    color:Colors.white70,
                    fontSize:18,
                  ),
                )

              ],
            ),


            Padding(

              padding: const EdgeInsets.all(30),

              child: Column(

                children:[

                  Row(
                    mainAxisAlignment:MainAxisAlignment.spaceAround,
                    children:[

                      CallButton(
                        icon:Icons.mic_off,
                        text:"كتم",
                        color:Colors.grey,
                        onTap:(){},
                      ),

                      CallButton(
                        icon:Icons.volume_up,
                        text:"سماعة",
                        color:Colors.grey,
                        onTap:(){},
                      ),

                      CallButton(
                        icon:Icons.videocam,
                        text:"فيديو",
                        color:Colors.grey,
                        onTap:(){},
                      ),

                    ],
                  ),


                  const SizedBox(height:40),


                  CircleAvatar(

                    radius:35,

                    backgroundColor:Colors.red,

                    child:IconButton(

                      icon:const Icon(
                        Icons.call_end,
                        color:Colors.white,
                        size:35,
                      ),

                      onPressed:(){

                        Navigator.pop(context);

                      },

                    ),

                  )

                ],

              ),

            )

          ],

        ),

      ),

    );

  }

}
