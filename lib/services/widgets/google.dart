import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

class CustomGoogleButton extends StatelessWidget {
  final VoidCallback onPressed;

  CustomGoogleButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FadeInUp(
      duration: Duration(milliseconds: 1900),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(colors: [
              Color.fromRGBO(211, 213, 248, 1),
              // Color.fromRGBO(143, 148, 251, 1),
              // Color.fromRGBO(143, 148, 251, .6),
              Color.fromRGBO(176, 180, 243, 0.6),
            ]),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/google.png', // Path to your Google logo asset
                height: 24,
                width: 24,
              ),
              SizedBox(width: 10),
              Text(
                "Sign in with Google",
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
