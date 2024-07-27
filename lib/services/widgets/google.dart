import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:travelist/services/styles.dart';

class CustomGoogleButton extends StatelessWidget {
  final VoidCallback onPressed;

  const CustomGoogleButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FadeInUp(
      duration: const Duration(milliseconds: 1900),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [
                AppColors.primaryColor,
                AppColors.secondaryColor,
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white,
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/google.png', // Path to your Google logo asset
                  height: 24,
                  width: 24,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Sign in with Google",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
