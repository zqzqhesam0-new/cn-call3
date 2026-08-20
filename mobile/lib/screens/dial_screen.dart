import 'dart:async';
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

  StreamSubscription? subscription;

  bool calling = false;
  String status = "";

  @override
  void initState() {
    super.initState();

    subscription = widget.socket.messages.listen((message) {
      final text = message.toString();

      if (text.startsWith("CALL_ACCEPTED:")) {
        final parts = text.split(":");

        if (parts.length < 3) return;

        final userId = parts[1];

        if (!mounted) return;

        setState(() {
          calling = false;
        });

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CallScreen(
              userId: userId,
            ),
          ),
        );
      }

      if (text.startsWith("CALL_ENDED:")) {
        if (!mounted) return;

        setState(() {
          calling = false;
          status = "انتهت المكالمة";
        });

        return;
      }

      if (text.startsWith("CALL_REJECTED:")) {
        if (!mounted) return;

        setState(() {
          calling = false;
          status = "تم رفض المكالمة";
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم رفض المكالمة"),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    controller.dispose();
    super.dispose();
  }

  void startCall() {
    final target = controller.text.trim();

    if (target.isEmpty) return;

    widget.socket.callUser(target);

    setState(() {
      calling = true;
      status = "جاري الاتصال...";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("اتصال بمستخدم"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(25),

        child: Column(
          children: [
            TextField(
              controller: controller,
              enabled: !calling,
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

            const SizedBox(height: 30),

            if (calling) ...[
              const CircularProgressIndicator(
                color: Colors.blue,
              ),

              const SizedBox(height: 20),

              Text(
                status,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {
                  widget.socket.endCall(controller.text.trim());

                  setState(() {
                    calling = false;
                    status = "";
                  });
                },
                child: const Text("إلغاء"),
              ),
            ] else ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.call),

                label: const Text("اتصال"),

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                ),

                onPressed: startCall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
