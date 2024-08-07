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
    _userFuture =
        FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
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
        SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile')),
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

  Future<void> _addInterest() async {
    if (_interestController.text.trim().isEmpty) return;
    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(widget.userId);
      final userDoc = await userRef.get();
      List<String> interests = List<String>.from(userDoc['interests']);
      interests.add(_interestController.text.trim().toLowerCase());
      await userRef.update({'interests': interests});
      _interestController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Interest added')),
      );
      setState(() {
        _userFuture = userRef.get();
      });
    } catch (e) {
      print('Error adding interest: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add interest')),
      );
    }
  }

  Future<void> _editInterest(String oldInterest, String newInterest) async {
    if (newInterest.trim().isEmpty) return;
    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(widget.userId);
      final userDoc = await userRef.get();
      List<String> interests = List<String>.from(userDoc['interests']);
      interests[interests.indexOf(oldInterest)] =
          newInterest.trim().toLowerCase();
      await userRef.update({'interests': interests});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Interest updated')),
      );
      setState(() {
        editingInterest = null;
        _userFuture = userRef.get();
      });
    } catch (e) {
      print('Error editing interest: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to edit interest')),
      );
    }
  }

  Future<void> _deleteInterest(String interest) async {
    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(widget.userId);
      final userDoc = await userRef.get();
      List<String> interests = List<String>.from(userDoc['interests']);
      interests.remove(interest);
      await userRef.update({'interests': interests});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Interest deleted')),
      );
      setState(() {
        _userFuture = userRef.get();
      });
    } catch (e) {
      print('Error deleting interest: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete interest')),
      );
    }
  }

  Future<void> _pickImage() async {
    final pickedImage =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        _image = File(pickedImage.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'User Profile',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryColor,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _userFuture,
        builder:
            (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSkeletonLoading();
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('User not found'));
          }

          Map<String, dynamic> data =
              snapshot.data!.data() as Map<String, dynamic>;

          if (_nameController.text.isEmpty) {
            _nameController.text = data['name'];
            _emailController.text = data['email'];
            _imageController.text = data['image'];
          }

          List<String> interests = data['interests']?.cast<String>() ?? [];

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: _image != null
                            ? FileImage(_image!)
                            : NetworkImage(_imageController.text),
                        onBackgroundImageError: (_, __) {
                          setState(() {
                            _image = null;
                          });
                        },
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            backgroundColor: AppColors.primaryColor,
                            child: Icon(Icons.edit, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _updateProfile,
                    child: Text(
                      'Update Profile',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                    ),
                  ),
                  SizedBox(height: 16),
                  Divider(),
                  SizedBox(height: 16),
                  Text(
                    'Interests',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: interests.length,
                    itemBuilder: (context, index) {
                      return Card(
                        child: ListTile(
                          title: editingInterest == interests[index]
                              ? TextField(
                                  controller: _interestController
                                    ..text = interests[index],
                                  onSubmitted: (newValue) {
                                    _editInterest(interests[index], newValue);
                                  },
                                )
                              : Text(interests[index]),
                          leading:
                              Icon(Icons.star, color: AppColors.primaryColor),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit,
                                    color: AppColors.secondaryColor),
                                onPressed: () {
                                  setState(() {
                                    editingInterest = interests[index];
                                    _interestController.text = interests[index];
                                  });
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete,
                                    color: AppColors.primaryColor),
                                onPressed: () {
                                  _showDeleteConfirmationDialog(
                                      interests[index]);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _interestController,
                    decoration: InputDecoration(
                      labelText: 'Add Interest',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.add),
                    ),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _addInterest,
                    child: Text(
                      'Add Interest',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showDeleteConfirmationDialog(String interest) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete Interest'),
          content: Text('Are you sure you want to delete this interest?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _deleteInterest(interest);
                Navigator.of(context).pop();
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkeletonLoading() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  child: Icon(Icons.person, size: 50, color: Colors.grey[400]),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    backgroundColor: Colors.grey[300],
                    child: Icon(Icons.edit, color: Colors.grey[400]),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 56,
              color: Colors.grey[300],
            ),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 56,
              color: Colors.grey[300],
            ),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 56,
              color: Colors.grey[300],
            ),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 40,
              color: Colors.grey[300],
            ),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 24,
              color: Colors.grey[300],
            ),
            SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: 3,
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    title: Container(
                      width: double.infinity,
                      height: 20,
                      color: Colors.grey[300],
                    ),
                    leading: Icon(Icons.star, color: Colors.grey[300]),
                  ),
                );
              },
            ),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 56,
              color: Colors.grey[300],
            ),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 40,
              color: Colors.grey[300],
            ),
          ],
        ),
      ),
    );
  }
}
