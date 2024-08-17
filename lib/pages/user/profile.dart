import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:travelist/services/shared_functions.dart';
import 'package:travelist/models/user_model.dart';
import 'package:travelist/services/styles.dart';
import 'package:travelist/services/widgets/image_picker.dart';
import 'view_profile.dart';

class UserProfilePage extends StatefulWidget {
  final Key? key;

  const UserProfilePage({this.key}) : super(key: key);
  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _interestController = TextEditingController();
  final TextEditingController _listController = TextEditingController();
  File? _image;
  late Future<DocumentSnapshot> _userFuture;
  bool isAdmin = false;
  List<UserModel> allUsers = [];
  List<Map<String, dynamic>> allLists = [];
  String selectedView = 'Interests';
  String? editingInterest;
  String? editingList;

  @override
  void initState() {
    super.initState();
    _userFuture =
        FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    var userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user?.uid)
        .get();
    var userData = userDoc.data() as Map<String, dynamic>;
    setState(() {
      isAdmin = userData['isAdmin'] ?? false;
    });

    if (isAdmin) {
      await _loadAllUsers();
      await _loadAllLists();
    }
  }

  Future<void> _loadAllUsers() async {
    var querySnapshot =
        await FirebaseFirestore.instance.collection('users').get();
    setState(() {
      allUsers = querySnapshot.docs
          .map((doc) => UserModel.fromJson(doc.data()))
          .toList();
    });
    print("All users loaded: $allUsers");
  }

  Future<void> _loadAllLists() async {
    var querySnapshot =
        await FirebaseFirestore.instance.collection('lists').get();
    setState(() {
      allLists = querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    });
  }

  Future<void> _updateProfile() async {
    try {
      String? imageUrl;
      if (_image != null) {
        imageUrl = await _uploadImageToFirebase(user!.uid);
      }

      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user!.uid);
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
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
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
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
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

  Future<void> _addInterest() async {
    if (_interestController.text.trim().isEmpty) return;
    try {
      await updateUserInterests(
          [_interestController.text.trim().toLowerCase()]);
      _interestController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Interest added',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
            ),
          ),
        ),
      );
      setState(() {
        _userFuture =
            FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      });
    } catch (e) {
      print('Error adding interest: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to add interest',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _editInterest(String oldInterest, String newInterest) async {
    if (newInterest.trim().isEmpty) return;
    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user!.uid);
      final userDoc = await userRef.get();
      List<String> interests = List<String>.from(userDoc['interests']);
      interests[interests.indexOf(oldInterest)] =
          newInterest.trim().toLowerCase();
      await userRef.update({'interests': interests});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Interest updated',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
            ),
          ),
        ),
      );
      setState(() {
        editingInterest = null;
        _userFuture = userRef.get();
      });
    } catch (e) {
      print('Error editing interest: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to edit interest',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _deleteInterest(String interest) async {
    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user!.uid);
      final userDoc = await userRef.get();
      List<String> interests = List<String>.from(userDoc['interests']);
      interests.remove(interest);
      await userRef.update({'interests': interests});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Interest deleted',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
            ),
          ),
        ),
      );
      setState(() {
        _userFuture = userRef.get();
      });
    } catch (e) {
      print('Error deleting interest: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete interest',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _addList() async {
    if (_listController.text.trim().isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('lists').add({
        'list': _listController.text.trim(),
        'userId': user?.uid,
      });
      _listController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'List added',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
            ),
          ),
        ),
      );
      setState(() {
        _loadAllLists();
      });
    } catch (e) {
      print('Error adding list: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to add list',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _editList(String listId, String newListName) async {
    if (newListName.trim().isEmpty) return;
    try {
      final listRef =
          FirebaseFirestore.instance.collection('lists').doc(listId);
      await listRef.update({'list': newListName.trim()});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'List updated',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
            ),
          ),
        ),
      );
      setState(() {
        editingList = null;
        _loadAllLists();
      });
    } catch (e) {
      print('Error editing list: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to edit list',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _deleteList(String listId) async {
    try {
      final listRef =
          FirebaseFirestore.instance.collection('lists').doc(listId);
      await listRef.delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'List deleted',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
            ),
          ),
        ),
      );
      setState(() {
        _loadAllLists();
      });
    } catch (e) {
      print('Error deleting list: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete list',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    final pickedImage = await pickImage(context);
    if (pickedImage != null) {
      setState(() {
        _image = pickedImage;
      });
    }
  }

  Future<void> _deleteUser(String userId) async {
    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(userId);
      await userRef.delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'User deleted',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
            ),
          ),
        ),
      );
      setState(() {
        _loadAllUsers();
      });
    } catch (e) {
      print('Error deleting user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete user',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _showDeleteUserConfirmationDialog(String userId) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Delete User',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(18.0) ?? 18.0,
            ),
          ),
          content: Text(
            'Are you sure you want to delete this user?',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ?? 16.0,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize:
                      MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ??
                          16.0,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                _deleteUser(userId);
                Navigator.of(context).pop();
              },
              child: Text(
                'Delete',
                style: TextStyle(
                  fontSize:
                      MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ??
                          16.0,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteListConfirmationDialog(String listId) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Delete List',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(18.0) ?? 18.0,
            ),
          ),
          content: Text(
            'Are you sure you want to delete this list?',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ?? 16.0,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize:
                      MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ??
                          16.0,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                _deleteList(listId);
                Navigator.of(context).pop();
              },
              child: Text(
                'Delete',
                style: TextStyle(
                  fontSize:
                      MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ??
                          16.0,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteProfileConfirmationDialog() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Delete Profile',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(18.0) ?? 18.0,
            ),
          ),
          content: Text(
            'Are you sure you want to delete your profile? This action cannot be undone.',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ?? 16.0,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize:
                      MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ??
                          16.0,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                _deleteProfile();
                Navigator.of(context).pop();
              },
              child: Text(
                'Delete',
                style: TextStyle(
                  fontSize:
                      MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ??
                          16.0,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteProfile() async {
    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user!.uid);
      await userRef.delete();
      await FirebaseAuth.instance.currentUser?.delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile deleted',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
            ),
          ),
        ),
      );
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      print('Error deleting profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete profile',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAdmin ? 'Admin Profile' : 'User Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize:
                MediaQuery.maybeTextScalerOf(context)?.scale(20.0) ?? 20.0,
          ),
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
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(
                  fontSize:
                      MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ??
                          16.0,
                ),
              ),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                'User not found',
                style: TextStyle(
                  fontSize:
                      MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ??
                          16.0,
                ),
              ),
            );
          }

          Map<String, dynamic> data =
              snapshot.data!.data() as Map<String, dynamic>? ?? {};

          String name = data['name'] ?? 'Unknown';
          String email = data['email'] ?? 'No email provided';
          String image = data['image'] ?? '';

          if (_nameController.text.isEmpty) {
            _nameController.text = name;
            _emailController.text = email;
            _imageController.text = image;
          }

          List<String> interests = (data['interests'] as List<dynamic>?)
                  ?.map((item) => item as String)
                  .toList() ??
              [];

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
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
                              : (image.isNotEmpty)
                                  ? NetworkImage(image)
                                  : AssetImage('assets/person.png')
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
                              16.0,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: MediaQuery.maybeTextScalerOf(context)
                                ?.scale(16.0) ??
                            16.0,
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
                              16.0,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: MediaQuery.maybeTextScalerOf(context)
                                ?.scale(16.0) ??
                            16.0,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isAdmin) ...[
                          Semantics(
                            label: "Manage selection",
                            child: Text(
                              'Manage',
                              style: TextStyle(
                                fontSize: MediaQuery.maybeTextScalerOf(context)
                                        ?.scale(16.0) ??
                                    16.0,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Semantics(
                            label: "Manage dropdown",
                            child: DropdownButton<String>(
                              value: selectedView,
                              items: ['Interests', 'Users', 'Lists']
                                  .map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: TextStyle(
                                      fontSize:
                                          MediaQuery.maybeTextScalerOf(context)
                                                  ?.scale(16.0) ??
                                              16.0,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedView = newValue!;
                                  if (selectedView == 'Lists') {
                                    _loadAllLists();
                                  }
                                });
                              },
                            ),
                          ),
                          SizedBox(width: 16),
                        ],
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
                                    16.0,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Semantics(
                    label: "Delete Profile button",
                    child: ElevatedButton(
                      onPressed: _showDeleteProfileConfirmationDialog,
                      child: Text(
                        'Delete Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: MediaQuery.maybeTextScalerOf(context)
                                  ?.scale(16.0) ??
                              16.0,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Divider(),
                  SizedBox(height: 16),
                  if (selectedView == 'Interests') ...[
                    Semantics(
                      label: "Interests section",
                      child: Text(
                        'Interests',
                        style: TextStyle(
                          fontSize: MediaQuery.maybeTextScalerOf(context)
                                  ?.scale(18.0) ??
                              18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Semantics(
                      label: "Add Interest input field",
                      child: TextField(
                        controller: _interestController,
                        decoration: InputDecoration(
                          labelText: 'Add Interest',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.add),
                          labelStyle: TextStyle(
                            fontSize: MediaQuery.maybeTextScalerOf(context)
                                    ?.scale(16.0) ??
                                16.0,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: MediaQuery.maybeTextScalerOf(context)
                                  ?.scale(16.0) ??
                              16.0,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Semantics(
                      label: "Add Interest button",
                      child: ElevatedButton(
                        onPressed: _addInterest,
                        child: Text(
                          'Add Interest',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: MediaQuery.maybeTextScalerOf(context)
                                    ?.scale(16.0) ??
                                16.0,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Semantics(
                      label: "List of interests",
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: interests.length,
                        itemBuilder: (context, index) {
                          return Card(
                            child: ListTile(
                              title: editingInterest == interests[index]
                                  ? Semantics(
                                      label: "Edit interest input field",
                                      child: TextField(
                                        controller: _interestController
                                          ..text = interests[index],
                                        onSubmitted: (newValue) {
                                          _editInterest(
                                              interests[index], newValue);
                                        },
                                        style: TextStyle(
                                          fontSize:
                                              MediaQuery.maybeTextScalerOf(
                                                          context)
                                                      ?.scale(16.0) ??
                                                  16.0,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      interests[index],
                                      style: TextStyle(
                                        fontSize: MediaQuery.maybeTextScalerOf(
                                                    context)
                                                ?.scale(16.0) ??
                                            16.0,
                                      ),
                                    ),
                              leading: Icon(Icons.star,
                                  color: AppColors.primaryColor),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit,
                                        color: AppColors.secondaryColor),
                                    onPressed: () {
                                      setState(() {
                                        editingInterest = interests[index];
                                        _interestController.text =
                                            interests[index];
                                      });
                                    },
                                    tooltip: "Edit interest",
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete,
                                        color: AppColors.primaryColor),
                                    onPressed: () {
                                      _showDeleteConfirmationDialog(
                                          interests[index]);
                                    },
                                    tooltip: "Delete interest",
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 16),
                  ] else if (selectedView == 'Users') ...[
                    Semantics(
                      label: "Users section",
                      child: Text(
                        'Users',
                        style: TextStyle(
                          fontSize: MediaQuery.maybeTextScalerOf(context)
                                  ?.scale(18.0) ??
                              18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Semantics(
                      label: "List of users",
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: allUsers.length,
                        itemBuilder: (context, index) {
                          return Card(
                            child: ListTile(
                              title: Flexible(
                                child: Text(
                                  allUsers[index].email,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize:
                                        MediaQuery.maybeTextScalerOf(context)
                                                ?.scale(16.0) ??
                                            16.0,
                                  ),
                                ),
                              ),
                              leading: Icon(Icons.person,
                                  color: AppColors.primaryColor),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit,
                                        color: AppColors.secondaryColor),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ViewUserProfilePage(
                                            userId: allUsers[index].uid,
                                          ),
                                        ),
                                      );
                                    },
                                    tooltip: "View user profile",
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete,
                                        color: AppColors.primaryColor),
                                    onPressed: () {
                                      _showDeleteUserConfirmationDialog(
                                          allUsers[index].uid);
                                    },
                                    tooltip: "Delete user",
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ] else if (selectedView == 'Lists') ...[
                    Semantics(
                      label: "Lists section",
                      child: Text(
                        'Lists',
                        style: TextStyle(
                          fontSize: MediaQuery.maybeTextScalerOf(context)
                                  ?.scale(18.0) ??
                              18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Semantics(
                      label: "List of all lists",
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: allLists.length,
                        itemBuilder: (context, index) {
                          var listId = allLists[index]['id'];
                          var listName =
                              allLists[index]['list'] ?? 'Unnamed List';
                          return Card(
                            child: ListTile(
                              title: editingList == listId
                                  ? Semantics(
                                      label: "Edit list input field",
                                      child: TextField(
                                        controller: _listController
                                          ..text = listName,
                                        onSubmitted: (newValue) {
                                          _editList(listId, newValue);
                                        },
                                        style: TextStyle(
                                          fontSize:
                                              MediaQuery.maybeTextScalerOf(
                                                          context)
                                                      ?.scale(16.0) ??
                                                  16.0,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      listName,
                                      style: TextStyle(
                                        fontSize: MediaQuery.maybeTextScalerOf(
                                                    context)
                                                ?.scale(16.0) ??
                                            16.0,
                                      ),
                                    ),
                              leading: Icon(Icons.list,
                                  color: AppColors.primaryColor),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit,
                                        color: AppColors.secondaryColor),
                                    onPressed: () {
                                      setState(() {
                                        editingList = listId;
                                        _listController.text = listName;
                                      });
                                    },
                                    tooltip: "Edit list",
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete,
                                        color: AppColors.primaryColor),
                                    onPressed: () {
                                      _showDeleteListConfirmationDialog(listId);
                                    },
                                    tooltip: "Delete list",
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
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
          title: Text(
            'Delete Interest',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(18.0) ?? 18.0,
            ),
          ),
          content: Text(
            'Are you sure you want to delete this interest?',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ?? 16.0,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize:
                      MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ??
                          16.0,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                _deleteInterest(interest);
                Navigator.of(context).pop();
              },
              child: Text(
                'Delete',
                style: TextStyle(
                  fontSize:
                      MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ??
                          16.0,
                ),
              ),
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
                        color: Colors.grey[300]),
                    leading: Icon(Icons.star, color: Colors.grey[300]),
                  ),
                );
              },
            ),
            SizedBox(height: 16),
            Container(
                width: double.infinity, height: 56, color: Colors.grey[300]),
            SizedBox(height: 8),
            Container(
                width: double.infinity, height: 40, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}
