import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travelist/services/functions.dart';
import 'package:travelist/services/styles.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Stream<bool> isLoggedInStream;
  final EdgeInsetsGeometry? padding; // Optional argument for padding
  CustomAppBar({
    Key? key,
    required this.title,
    required this.isLoggedInStream,
    this.padding,
  }) : super(key: key);
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20.0,
              ),
            ),
            centerTitle: true,
            backgroundColor: AppColors.primaryColor,
            actions: <Widget>[
              IconButton(
                icon: Icon(Icons.logout),
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
                style: TextStyle(
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
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
