import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatelessWidget {
  final String callerId;
  final String callerName;
  final SocketService socket;

  const IncomingCallScreen({
    super.key,
    required this.callerId,
    required this.callerName,
    required this.socket,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 55),

            const Text(
              "مكالمة واردة",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 17,
              ),
            ),

            const Spacer(),

            Container(
              width: 145,
              height: 145,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xff252525),
                border: Border.all(
                  color: Colors.white12,
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.person,
                size: 88,
                color: Colors.white70,
              ),
            ),

            const SizedBox(height: 28),

            Text(
              callerName.isEmpty ? callerId : callerName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 31,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              callerId,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 18,
              ),
            ),

            const Spacer(),

            const Text(
              "مكالمة صوتية",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 15,
              ),
            ),

            const SizedBox(height: 30),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 55),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CallAction(
                    icon: Icons.call_end,
                    label: "رفض",
                    color: Colors.red,
                    onTap: () {
                      socket.rejectCall(callerId);
                      Navigator.pop(context);
                    },
                  ),

                  _CallAction(
                    icon: Icons.call,
                    label: "قبول",
                    color: Colors.green,
                    onTap: () {
                      socket.acceptCall(callerId);

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
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _CallAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 34,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
