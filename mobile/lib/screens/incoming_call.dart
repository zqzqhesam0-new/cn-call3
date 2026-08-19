import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import 'call.dart';


class IncomingCallScreen extends StatelessWidget {

  final String callerId;
  final SocketService socket;


  const IncomingCallScreen({
    super.key,
    required this.callerId,
    required this.socket,
  });



  @override
  Widget build(BuildContext context){

    return Scaffold(

      backgroundColor: Colors.black,


      body: SafeArea(

        child: Column(

          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,


          children: [


            const SizedBox(height:50),



            Column(

              children: [


                CircleAvatar(

                  radius:75,

                  backgroundColor:
                      Colors.grey.shade800,


                  child: const Icon(

                    Icons.person,

                    size:90,

                    color:Colors.white,

                  ),

                ),



                const SizedBox(height:30),



                Text(

                  callerId,

                  style: const TextStyle(

                    color:Colors.white,

                    fontSize:32,

                    fontWeight:
                        FontWeight.bold,

                  ),

                ),



                const SizedBox(height:15),



                const Text(

                  "مكالمة واردة",

                  style: TextStyle(

                    color:Colors.white70,

                    fontSize:20,

                  ),

                ),


              ],

            ),




            Padding(

              padding:
                  const EdgeInsets.only(
                    bottom:50,
                  ),


              child: Row(

                mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly,


                children: [



                  FloatingActionButton(

                    heroTag:"reject",

                    backgroundColor:
                        Colors.red,


                    child: const Icon(

                      Icons.call_end,

                      color:Colors.white,

                    ),


                    onPressed:(){

                      Navigator.pop(context);

                    },

                  ),





                  FloatingActionButton(

                    heroTag:"accept",

                    backgroundColor:
                        Colors.green,


                    child: const Icon(

                      Icons.call,

                      color:Colors.white,

                    ),


                    onPressed:(){

                        socket.acceptCall(
                        callerId,
                      );

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CallScreen(
                            userId: callerId,
                          ),
                        ),
                      );

                    },

                  ),



                ],

              ),

            )



          ],


        ),

      ),

    );

  }


}
