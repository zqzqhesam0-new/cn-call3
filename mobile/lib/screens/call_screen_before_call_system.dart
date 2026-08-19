import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/call_button.dart';


class CallScreen extends StatefulWidget {

  final String userId;

  const CallScreen({
    super.key,
    required this.userId,
  });


  @override
  State<CallScreen> createState() => _CallScreenState();

}


class _CallScreenState extends State<CallScreen> {


  int seconds = 0;
  Timer? timer;


  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {

        setState(() {
          seconds++;
        });

      },
    );

  }


  @override
  void dispose() {

    timer?.cancel();

    super.dispose();
  }



  String get timeText {

    final m = (seconds ~/ 60)
        .toString()
        .padLeft(2,'0');

    final s = (seconds % 60)
        .toString()
        .padLeft(2,'0');

    return "$m:$s";

  }



  @override
  Widget build(BuildContext context){

    return Scaffold(

      backgroundColor: const Color(0xff101010),


      body: SafeArea(

        child: Column(

          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,


          children: [


            const SizedBox(height:40),



            Column(

              children: [


                Container(

                  width:150,
                  height:150,

                  decoration: BoxDecoration(

                    shape: BoxShape.circle,

                    color: Colors.grey.shade800,

                  ),


                  child: const Icon(

                    Icons.person,

                    size:90,

                    color:Colors.white70,

                  ),

                ),



                const SizedBox(height:25),



                Text(

                  widget.userId,

                  style: const TextStyle(

                    color:Colors.white,

                    fontSize:30,

                    fontWeight:FontWeight.bold,

                  ),

                ),



                const SizedBox(height:12),



                Text(

                  timeText,

                  style: const TextStyle(

                    color:Colors.white70,

                    fontSize:20,

                  ),

                ),


              ],

            ),




            Padding(

              padding:
                  const EdgeInsets.only(
                    left:25,
                    right:25,
                    bottom:35,
                  ),


              child: Column(

                children: [


                  Row(

                    mainAxisAlignment:
                        MainAxisAlignment.spaceEvenly,


                    children:[


                      CallButton(
                        icon:Icons.mic_off,
                        text:"كتم",
                        color:Colors.grey.shade800,
                        onTap:(){},
                      ),



                      CallButton(
                        icon:Icons.volume_up,
                        text:"سماعة",
                        color:Colors.grey.shade800,
                        onTap:(){},
                      ),



                      CallButton(
                        icon:Icons.videocam,
                        text:"فيديو",
                        color:Colors.grey.shade800,
                        onTap:(){},
                      ),


                    ],

                  ),



                  const SizedBox(height:45),



                  CircleAvatar(

                    radius:36,

                    backgroundColor:
                        Colors.red,


                    child:IconButton(

                      icon:
                          const Icon(

                            Icons.call_end,

                            color:Colors.white,

                            size:38,

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
