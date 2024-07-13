import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:travelist/bloc/auth_bloc.dart';
import 'package:travelist/services/styles.dart';
import 'package:travelist/services/widgets/app_bar.dart';

class UserProfilePage extends StatefulWidget {
  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  User? currentUser;
  bool isLoading = true;
  String userName = '';
  String userPhoto = '';

  @override
  void initState() {
    super.initState();
    // Retrieve the current user when the widget is first created
    currentUser = FirebaseAuth.instance.currentUser;
    retrieveUserData();
  }

  Future<void> retrieveUserData() async {
    if (currentUser!.providerData[0].providerId == 'password') {
      // Custom user login, retrieve the user document
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      // Get the value of the 'name' and 'image' fields from the user document
      final userData = userDoc.data() as Map<String, dynamic>?;
      setState(() {
        userName = userData?['name'] ?? '';
        userPhoto = userData?['image'] ?? '';
        isLoading = false;
      });
    } else {
      // Social login, use 'displayName' field
      setState(() {
        userName = currentUser!.displayName ?? '';
        userPhoto = currentUser!.photoURL ?? '';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthBloc>();

    return Scaffold(
      appBar:
          CustomAppBar(title: 'Profile', isLoggedInStream: authService.stream),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Center(
              child: Transform.translate(
                offset: Offset(0, -60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 16),
                    CircleAvatar(
                      radius: 50,
                      backgroundImage:
                          userPhoto.isNotEmpty ? NetworkImage(userPhoto) : null,
                      child: userPhoto.isEmpty
                          ? Icon(Icons.person, size: 50)
                          : null,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Name: $userName',
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Email: ${currentUser!.email}',
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        context.read<AuthBloc>().add(LoggedOut());
                        Navigator.pop(context);
                      },
                      child: Text('Sign Out'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
