import 'package:web_socket_channel/web_socket_channel.dart';


class SocketService {

  WebSocketChannel? channel;


  void connect(String id){

    channel = WebSocketChannel.connect(

      Uri.parse(
        "wss://ubiquitous-acorn-x9wwxwr9x4rcvq57-8080.app.github.dev/ws/$id"
      ),

    );

  }



  void callUser(String target){

    channel?.sink.add(
      "CALL_REQUEST:$target"
    );

  }


  void acceptCall(String callerId){

    channel?.sink.add(
      "ACCEPT_CALL:$callerId"
    );

  }


  void rejectCall(String callerId){

    channel?.sink.add(
      "REJECT_CALL:$callerId"
    );

  }



  Stream get messages {

    return channel!.stream;

  }



  void close(){

    channel?.sink.close();

  }


}
