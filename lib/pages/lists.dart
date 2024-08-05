// Importing necessary Flutter and Firebase packages for UI components and database functionalities.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:travelist/pages/list_detail.dart';
import 'package:travelist/services/shared_functions.dart';
import 'package:travelist/services/styles.dart';

// ListsPage is a stateful widget that displays a list of user-created lists.
class ListsPage extends StatefulWidget {
  const ListsPage({super.key});

  @override
  _ListsPageState createState() => _ListsPageState();
}

// State class for ListsPage
class _ListsPageState extends State<ListsPage> {
  // Reference to the Firestore collection for storing lists
  final CollectionReference _listsCollection =
      FirebaseFirestore.instance.collection('lists');

  // Variables to manage the state of the UI
  int _selectedIndex = 1;
  User? _currentUser;

  // Initialize the state and retrieve the current user
  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser; // Get the current user
  }

  // Handle bottom navigation bar item taps
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index; // Update the selected index
    });
    if (index == 0) {
      Navigator.pushNamed(context, '/'); // Navigate to HomePage if index is 0
    }
  }

  // Build method to create the UI for ListsPage
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // App bar with title
      appBar: AppBar(
        title: Text(
          'Lists',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryColor,
      ),
      // Body of the page with a list of user-created lists
      body: StreamBuilder<QuerySnapshot>(
        stream: _listsCollection
            .where('userId', isEqualTo: _currentUser?.uid)
            .snapshots(), // Stream of lists filtered by user ID
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child:
                    CircularProgressIndicator()); // Show loading indicator if no data
          }

          // Retrieve the list of documents from the snapshot
          var lists = snapshot.data!.docs;

          // ListView builder to create a list of ListTiles for each list
          return ListView.builder(
            itemCount: lists.length, // Number of items in the list
            itemBuilder: (context, index) {
              // Retrieve the data for each list
              var listData = lists[index].data() as Map<String, dynamic>;
              return FutureBuilder<QuerySnapshot>(
                future: _listsCollection
                    .doc(lists[index].id)
                    .collection('pois')
                    .get(), // Future to get the list of POIs for the list
                builder: (context, poiSnapshot) {
                  if (!poiSnapshot.hasData) {
                    return ListTile(
                      title: Text(listData.containsKey('list')
                          ? listData['list']
                          : 'Unnamed List'), // Show the list name
                      subtitle: const Text('Loading...'), // Show loading text
                    );
                  }

                  // Retrieve the list of POIs
                  var pois = poiSnapshot.data!.docs;

                  // Create a ListTile for each list with the number of POIs
                  return ListTile(
                    title: Text(listData.containsKey('list')
                        ? listData['list']
                        : 'Unnamed List'), // Show the list name
                    subtitle: Text(
                        '${pois.length} places'), // Show the number of POIs
                    onTap: () {
                      // Navigate to ListDetailsPage when the ListTile is tapped
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ListDetailsPage(
                            listId: lists[index].id,
                            listName: listData['list'],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
      // Floating action button to add a new list
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            _showAddListDialog(context), // Show dialog to add a new list
        tooltip: 'Add New List',
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  // Show a dialog to add a new list
  void _showAddListDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>(); // Key to validate the form
    final listNameController =
        TextEditingController(); // Controller for the list name input field

    showDialog(
      context: context, // Context of the current widget
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New List'), // Title of the dialog
          content: Form(
            key: formKey, // Form key for validation
            child: TextFormField(
              controller: listNameController, // Controller for the input field
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a list name'; // Validation error message
                }
                return null;
              },
              decoration: const InputDecoration(
                  hintText: 'List Name'), // Input field decoration
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog without saving
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  // Check if the form input is valid
                  await createList(listNameController.text,
                      _listsCollection); // Create a new list
                  Navigator.of(context).pop(); // Close the dialog after saving
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
