import 'package:flutter/material.dart';

class CallButton extends StatelessWidget {

  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback onTap;

  const CallButton({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    required this.onTap,
  });


  @override
  Widget build(BuildContext context){

    return Column(
      children: [

        InkWell(
          onTap: onTap,
          child: CircleAvatar(
            radius: 32,
            backgroundColor: color,
            child: Icon(
              icon,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),

        const SizedBox(height:8),

        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize:12,
          ),
        )

      ],
    );

  }

}
