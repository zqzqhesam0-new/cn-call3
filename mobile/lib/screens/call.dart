import 'package:flutter/material.dart';
import '../services/socket_service.dart';

class CallScreen extends StatefulWidget {

  final String userId;
  final SocketService socket;
  final bool isCaller;

  const CallScreen({
    super.key,
    required this.userId,
    required this.socket,
    required this.isCaller,
  });


  @override
  State<CallScreen> createState() => _CallScreenState();
}


class _CallScreenState extends State<CallScreen> {

  bool micOff = false;
  bool speakerOn = false;
  bool videoOn = false;


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.black,

      body: SafeArea(

        child: Column(

          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [

            const SizedBox(height: 40),


            Column(
              children: [

                CircleAvatar(
                  radius: 65,
                  backgroundColor: Colors.grey.shade800,
                  child: const Icon(
                    Icons.person,
                    size: 80,
                    color: Colors.white,
                  ),
                ),


                const SizedBox(height: 25),


                Text(
                  widget.userId,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),


                const SizedBox(height: 10),


                const Text(
                  "جاري الاتصال...",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),

              ],
            ),



            Padding(

              padding: const EdgeInsets.only(bottom: 40),

              child: Row(

                mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                children: [


                  _button(
                    icon: micOff
                        ? Icons.mic_off
                        : Icons.mic,
                    active: micOff,
                    onTap: (){
                      setState(() {
                        micOff = !micOff;
                      });
                    },
                  ),



                  _button(
                    icon: speakerOn
                        ? Icons.volume_up
                        : Icons.volume_down,
                    active: speakerOn,
                    onTap: (){
                      setState(() {
                        speakerOn = !speakerOn;
                      });
                    },
                  ),



                  _button(
                    icon: videoOn
                        ? Icons.videocam
                        : Icons.videocam_off,
                    active: videoOn,
                    onTap: (){
                      setState(() {
                        videoOn = !videoOn;
                      });
                    },
                  ),



                  FloatingActionButton(
                    backgroundColor: Colors.red,
                    onPressed: (){
                      Navigator.pop(context);
                    },
                    child: const Icon(
                      Icons.call_end,
                      color: Colors.white,
                    ),
                  ),


                ],

              ),

            )


          ],

        ),

      ),

    );

  }



  Widget _button({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {

    return CircleAvatar(

      radius: 28,

      backgroundColor: active
          ? Colors.white
          : Colors.grey.shade800,

      child: IconButton(

        onPressed: onTap,

        icon: Icon(
          icon,
          color: active
              ? Colors.black
              : Colors.white,
        ),

      ),

    );

  }

}
