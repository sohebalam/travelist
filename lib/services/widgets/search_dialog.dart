import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:travelist/pages/chat/chat_page.dart';

void showSearchDialog(BuildContext context, User? currentUser) {
  showDialog(
    context: context,
    builder: (context) => SearchDialog(currentUser: currentUser),
  );
}

class SearchDialog extends StatefulWidget {
  final User? currentUser;

  const SearchDialog({super.key, this.currentUser});

  @override
  _SearchDialogState createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  TextEditingController searchController = TextEditingController();
  List<DocumentSnapshot> searchResults = [];

  void searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
      });
      return;
    }

    try {
      final usersCollection = FirebaseFirestore.instance.collection('users');

      final searchByName = await usersCollection
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      final searchByEmail = await usersCollection
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      final allResults = searchByName.docs + searchByEmail.docs;
      final filteredResults =
          allResults.where((doc) => doc.id != widget.currentUser!.uid).toList();

      setState(() {
        searchResults = filteredResults;
      });

      print("Search results for query '$query': ${searchResults.length}");
    } catch (e) {
      print("Error searching users: $e");
    }
  }

  Widget buildSearchResults() {
    return searchResults.isEmpty
        ? const Center(child: Text('No users found.'))
        : ListView.builder(
            shrinkWrap: true,
            itemCount: searchResults.length,
            itemBuilder: (context, index) {
              var user = searchResults[index];
              var userData = user.data() as Map<String, dynamic>?;
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage:
                      userData != null && userData.containsKey('image')
                          ? NetworkImage(userData['image'])
                          : const AssetImage('assets/person.png') as ImageProvider,
                ),
                title: Text(userData != null && userData.containsKey('name')
                    ? userData['name']
                    : ''),
                subtitle: Text(userData != null && userData.containsKey('email')
                    ? userData['email']
                    : ''),
                onTap: () async {
                  if (user.id.isNotEmpty && widget.currentUser != null) {
                    // Check if a conversation already exists between the users
                    var existingConversations = await FirebaseFirestore.instance
                        .collection('chats')
                        .where('participants',
                            arrayContains: widget.currentUser!.uid)
                        .get();

                    DocumentSnapshot? conversationDoc;

                    if (existingConversations.docs.isNotEmpty) {
                      try {
                        conversationDoc = existingConversations.docs.firstWhere(
                          (doc) =>
                              (doc['participants'] as List).contains(user.id),
                        );
                      } catch (e) {
                        // If no conversation exists, create a new one
                        var newConversation = await FirebaseFirestore.instance
                            .collection('chats')
                            .add({
                          'participants': [widget.currentUser!.uid, user.id],
                          'lastMessage': '',
                          'lastMessageTime': FieldValue.serverTimestamp(),
                        });
                        conversationDoc = await newConversation.get();
                      }
                    } else {
                      // Create a new conversation if none exist
                      var newConversation = await FirebaseFirestore.instance
                          .collection('chats')
                          .add({
                        'participants': [widget.currentUser!.uid, user.id],
                        'lastMessage': '',
                        'lastMessageTime': FieldValue.serverTimestamp(),
                      });
                      conversationDoc = await newConversation.get();
                    }

                    Navigator.pop(context); // Close the search results
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(
                          currentUserId: widget.currentUser!.uid,
                          u_id: user.id, // Pass the correct user ID here
                        ),
                      ),
                    );
                  } else {
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    searchUsers(searchController.text);
                  },
                ),
              ),
              onChanged: (value) {
                searchUsers(value);
              },
            ),
          ),
          Expanded(
            child: buildSearchResults(),
          ),
        ],
      ),
    );
  }
}
