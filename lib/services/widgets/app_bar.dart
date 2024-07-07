import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:travelist/services/styles.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Stream<bool> isLoggedInStream;
  final EdgeInsetsGeometry? padding; // Optional argument for padding
  const CustomAppBar({
    super.key,
    required this.title,
    required this.isLoggedInStream,
    this.padding,
  });
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: isLoggedInStream,
      initialData: false,
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          // User is logged in, display default AppBar
          return AppBar(
            title: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20.0,
              ),
            ),
            centerTitle: true,
            backgroundColor: AppColors.primaryColor,
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () {
                  disconnect();
                },
              ),
            ],
          );
        } else {
          // User is logged out, apply padding
          return AppBar(
            title: Padding(
              padding: padding ?? EdgeInsets.zero,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20.0,
                ),
              ),
            ),
            centerTitle: true,
            backgroundColor: AppColors.primaryColor,
            actions: null,
          );
        }
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

final _auth = FirebaseAuth.instance;
Future<void> disconnect() async {
// User? get user => _auth.currentUser;
  await _auth.signOut();
}
