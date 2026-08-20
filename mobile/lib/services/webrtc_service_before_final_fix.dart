import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'socket_service.dart';


class WebRTCService {

  final SocketService socket;

  final String target;

  RTCPeerConnection? peer;

  MediaStream? localStream;


  WebRTCService(
    this.socket,
    this.target,
  );



  Future<void> initialize() async {

    try {

      localStream =
          await navigator.mediaDevices.getUserMedia({

        "audio": true,

        "video": false,

      });

    } catch(e){

      // Microphone permission failed, continue without local audio

    }


    peer = await createPeerConnection({

      "iceServers":[

        {
          "urls":
          "stun:stun.l.google.com:19302"
        }

      ]

    });



    if(localStream != null){

      for(var track in localStream!.getTracks()){

        await peer!.addTrack(
          track,
          localStream!,
        );

      }

    }



    peer!.onIceCandidate = (candidate){

      if(candidate.candidate != null){

        socket.sendIceCandidate(
          target,
          candidate.candidate!,
        );

      }

    };

  }



  Future<void> createOffer() async {

    final offer =
        await peer!.createOffer();


    await peer!.setLocalDescription(
      offer,
    );


    socket.sendOffer(
      target,
      offer.sdp!,
    );

  }



  Future<void> createAnswer(
      String offer
      ) async {


    await peer!.setRemoteDescription(

      RTCSessionDescription(
        offer,
        "offer",
      ),

    );


    final answer =
        await peer!.createAnswer();


    await peer!.setLocalDescription(
      answer,
    );


    socket.sendAnswer(
      target,
      answer.sdp!,
    );

  }



  Future<void> setAnswer(
      String answer
      ) async {


    await peer!.setRemoteDescription(

      RTCSessionDescription(
        answer,
        "answer",
      ),

    );

  }



  Future<void> addIce(
      String ice
      ) async {


    await peer!.addCandidate(

      RTCIceCandidate(
        ice,
        "",
        0,
      ),

    );

  }



  void close(){

    localStream?.dispose();

    peer?.close();

  }

}
