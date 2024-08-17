import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:travelist/services/shared_functions.dart';
import 'package:travelist/services/styles.dart';
import 'package:travelist/services/widgets/image_picker.dart';

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

  Future<void> _updateProfile() async {
    try {
      String? imageUrl;
      if (_image != null) {
        imageUrl = await _uploadImageToFirebase(widget.userId);
      }

      final userRef =
          FirebaseFirestore.instance.collection('users').doc(widget.userId);
      await userRef.update({
        'name': _nameController.text,
        'email': _emailController.text,
        'image': imageUrl ?? _imageController.text,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile updated successfully',
            style: TextStyle(
              fontSize: MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ??
                  14.0, // Adjustable text
            ),
          ),
        ),
      );
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update profile',
            style: TextStyle(
              fontSize: MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ??
                  14.0, // Adjustable text
            ),
          ),
        ),
      );
    }
  }

  Future<String> _uploadImageToFirebase(String userId) async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('user_images')
        .child('$userId.jpg');
    UploadTask uploadTask = storageRef.putFile(_image!);
    TaskSnapshot taskSnapshot = await uploadTask;
    return await taskSnapshot.ref.getDownloadURL();
  }

  void _confirmDeleteProfile() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Confirm Deletion',
            style: TextStyle(
              fontSize: MediaQuery.maybeTextScalerOf(context)?.scale(18.0) ??
                  18.0, // Adjustable text
            ),
          ),
          content: Text(
            'Are you sure you want to delete your profile? This action cannot be undone.',
            style: TextStyle(
              fontSize: MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ??
                  16.0, // Adjustable text
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize:
                      MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ??
                          16.0, // Adjustable text
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                'Delete',
                style: TextStyle(
                  fontSize:
                      MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ??
                          16.0, // Adjustable text
                ),
              ),
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
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .delete();
      Navigator.of(context).pop(); // Navigate back after deletion
    } catch (e) {
      print('Error deleting profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error deleting profile',
            style: TextStyle(
              fontSize: MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ??
                  14.0, // Adjustable text
            ),
          ),
        ),
      );
    }
    setState(() {});
  }

  Future<void> _pickImage() async {
    final pickedImage = await pickImage(context);
    if (pickedImage != null) {
      setState(() {
        _image = pickedImage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'View Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: MediaQuery.maybeTextScalerOf(context)?.scale(20.0) ??
                20.0, // Adjustable text
          ),
        ),
        backgroundColor: AppColors.primaryColor,
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
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
              return Center(
                child: Text(
                  'Error loading profile',
                  style: TextStyle(
                    fontSize:
                        MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ??
                            16.0, // Adjustable text
                  ),
                ),
              );
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(
                child: Text(
                  'Profile not found',
                  style: TextStyle(
                    fontSize:
                        MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ??
                            16.0, // Adjustable text
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Semantics(
                      label: "Profile picture",
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: _image != null
                            ? FileImage(_image!)
                            : (_imageController.text.isNotEmpty
                                    ? NetworkImage(_imageController.text)
                                    : AssetImage('assets/default_profile.png'))
                                as ImageProvider,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Semantics(
                        label: "Edit profile picture",
                        child: InkWell(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            backgroundColor: AppColors.primaryColor,
                            child: Icon(Icons.edit, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Semantics(
                  label: "Name input field",
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                      labelStyle: TextStyle(
                        fontSize: MediaQuery.maybeTextScalerOf(context)
                                ?.scale(16.0) ??
                            16.0, // Adjustable text
                      ),
                    ),
                    style: TextStyle(
                      fontSize:
                          MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ??
                              16.0, // Adjustable text
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Semantics(
                  label: "Email input field",
                  child: TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                      labelStyle: TextStyle(
                        fontSize: MediaQuery.maybeTextScalerOf(context)
                                ?.scale(16.0) ??
                            16.0, // Adjustable text
                      ),
                    ),
                    style: TextStyle(
                      fontSize:
                          MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ??
                              16.0, // Adjustable text
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Semantics(
                  label: "Update Profile button",
                  child: ElevatedButton(
                    onPressed: _updateProfile,
                    child: Text(
                      'Update Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: MediaQuery.maybeTextScalerOf(context)
                                ?.scale(16.0) ??
                            16.0, // Adjustable text
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondaryColor,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Semantics(
                  label: "Delete Profile button",
                  child: ElevatedButton(
                    onPressed: _confirmDeleteProfile,
                    child: Text(
                      'Delete Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: MediaQuery.maybeTextScalerOf(context)
                                ?.scale(16.0) ??
                            16.0, // Adjustable text
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
