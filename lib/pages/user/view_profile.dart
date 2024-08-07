import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:travelist/services/styles.dart'; // For current user information

class ViewUserProfilePage extends StatefulWidget {
  final String userId;

  ViewUserProfilePage({required this.userId});

  @override
  _ViewUserProfilePageState createState() => _ViewUserProfilePageState();
}

class _ViewUserProfilePageState extends State<ViewUserProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _interestController = TextEditingController();
  File? _image;
  late Future<DocumentSnapshot> _userFuture;
  String? editingInterest;

  @override
  void initState() {
    super.initState();
    _userFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get()
        .then((userDoc) {
      final userData = userDoc.data();
      if (userData != null) {
        _nameController.text = userData['name'] ?? '';
        _emailController.text = userData['email'] ?? '';
        _imageController.text = userData['image'] ?? '';
      }
      return userDoc;
    });
  }

  void _updateProfile() {
    print("Update profile button pressed");
    // Add your update profile logic here
    setState(() {});
  }

  void _confirmDeleteProfile() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text(
              'Are you sure you want to delete your profile? This action cannot be undone.'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteProfile();
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteProfile() async {
    print("Delete profile button pressed");
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .delete();
      // Add additional deletion logic if needed (e.g., deleting user-related data from other collections)
      Navigator.of(context).pop(); // Navigate back after deletion
    } catch (e) {
      print('Error deleting profile: $e');
      // Show an error message if the deletion fails
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error deleting profile')));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    print("Building ViewUserProfilePage widget");
    return Scaffold(
      appBar: AppBar(
        title: Text('View Profile'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: FutureBuilder<DocumentSnapshot>(
          future: _userFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error loading profile'));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(child: Text('Profile not found'));
            }

            return Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: _imageController.text.isEmpty
                      ? AssetImage('assets/default_profile.png')
                      : NetworkImage(_imageController.text) as ImageProvider,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: 'Name'),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: 'Email'),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _updateProfile,
                  child: Text('Update Profile'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
