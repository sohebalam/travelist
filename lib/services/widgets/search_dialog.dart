// Import necessary packages
import 'package:cloud_firestore/cloud_firestore.dart'; // For accessing Firestore database
import 'package:firebase_auth/firebase_auth.dart'; // For Firebase Authentication
import 'package:flutter/material.dart'; // Flutter framework
import 'package:travelist/pages/chat/chat_page.dart'; // Chat page component

// Function to show a search dialog
void showSearchDialog(BuildContext context, User? currentUser) {
  showDialog(
    context: context,
    builder: (context) =>
        SearchDialog(currentUser: currentUser), // Displays SearchDialog widget
  );
}

// Stateful widget for the search dialog
class SearchDialog extends StatefulWidget {
  final User? currentUser; // The currently logged-in user

  const SearchDialog({super.key, this.currentUser});

  @override
  _SearchDialogState createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  TextEditingController searchController =
      TextEditingController(); // Controller for the search input field
  List<DocumentSnapshot> searchResults = []; // List to store search results

  // Function to search users by name or email
  void searchUsers(String query) async {
    if (query.isEmpty) {
      // Clear search results if the query is empty
      setState(() {
        searchResults = [];
      });
      return;
    }

    try {
      // Reference to the 'users' collection in Firestore
      final usersCollection = FirebaseFirestore.instance.collection('users');

      // Search users by name
      final searchByName = await usersCollection
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      // Search users by email
      final searchByEmail = await usersCollection
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      // Combine search results and exclude current user from the results
      final allResults = searchByName.docs + searchByEmail.docs;
      final filteredResults =
          allResults.where((doc) => doc.id != widget.currentUser!.uid).toList();

      // Update the state with the search results
      setState(() {
        searchResults = filteredResults;
      });

      // Debugging log
      print("Search results for query '$query': ${searchResults.length}");
    } catch (e) {
      // Handle errors in the search process
      print("Error searching users: $e");
    }
  }

  // Function to build the search results list
  Widget buildSearchResults() {
    return searchResults.isEmpty
        ? const Center(
            child: Text('No users found.')) // Display message if no users found
        : ListView.builder(
            shrinkWrap: true, // Makes ListView adapt to the content size
            itemCount: searchResults.length, // Number of items in the list
            itemBuilder: (context, index) {
              var user = searchResults[index]; // Get user document
              var userData = user.data()
                  as Map<String, dynamic>?; // Get user data as a map

              return ListTile(
                // Display user profile image
                leading: CircleAvatar(
                  backgroundImage: userData != null &&
                          userData.containsKey('image')
                      ? NetworkImage(userData['image']) // User's profile image
                      : const AssetImage('assets/person.png')
                          as ImageProvider, // Default image
                ),
                // Display user name
                title: Text(userData != null && userData.containsKey('name')
                    ? userData['name']
                    : ''),
                // Display user email
                subtitle: Text(userData != null && userData.containsKey('email')
                    ? userData['email']
                    : ''),
                // Action when a user is tapped
                onTap: () async {
                  if (user.id.isNotEmpty && widget.currentUser != null) {
                    // Check if a conversation already exists between the users
                    var existingConversations = await FirebaseFirestore.instance
                        .collection('chats')
                        .where('participants',
                            arrayContains: widget.currentUser!.uid)
                        .get();

                    DocumentSnapshot? conversationDoc;

                    try {
                      // Try to find an existing conversation
                      conversationDoc = existingConversations.docs.firstWhere(
                        (doc) =>
                            (doc['participants'] as List).contains(user.id),
                      );
                    } catch (e) {
                      // If no conversation exists, create a new one
                      var newConversation = await FirebaseFirestore.instance
                          .collection('chats')
                          .add({
                        'participants': [
                          widget.currentUser!.uid,
                          user.id
                        ], // Add participants
                        'lastMessage': '', // Placeholder for the last message
                        'lastMessageTime': FieldValue
                            .serverTimestamp(), // Timestamp of the last message
                      });
                      conversationDoc = await newConversation
                          .get(); // Get the new conversation document
                    }

                    Navigator.pop(context); // Close the search dialog
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(
                          currentUserId:
                              widget.currentUser!.uid, // Current user ID
                          u_id: user.id, // Other user's ID
                          userName: userData?['name'] ??
                              'Unknown', // Other user's name
                          userImage:
                              userData?['image'] ?? '', // Other user's image
                        ),
                      ),
                    );
                  } else {
                    // Handle invalid user information
                    print('Invalid user information');
                  }
                },
              );
            },
          );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min, // Set the minimum size of the column
        children: [
          // Search input field
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController, // Controller for the search input
              decoration: InputDecoration(
                hintText: 'Search users...', // Placeholder text
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0), // Rounded corners
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search), // Search icon
                  onPressed: () {
                    searchUsers(searchController
                        .text); // Perform search on button press
                  },
                ),
              ),
              onChanged: (value) {
                searchUsers(value); // Perform search on text change
              },
            ),
          ),
          // Display search results
          Expanded(
            child: buildSearchResults(),
          ),
        ],
      ),
    );
  }
}
