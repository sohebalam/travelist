// Import necessary packages
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:travelist/services/styles.dart';
import 'package:travelist/services/widgets/search_dialog.dart';
import 'chat_page.dart';

// Define a stateful widget for the chat list
class ChatList extends StatefulWidget {
  const ChatList({super.key});

  @override
  _ChatListState createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  User? currentUser;

  @override
  void initState() {
    super.initState();
    // Get the current authenticated user
    currentUser = FirebaseAuth.instance.currentUser;
    // If there is no current user, navigate to the authentication screen
    if (currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/auth');
      });
    } else {
      // Print the current user's ID for debugging purposes
      print('Current user ID: ${currentUser!.uid}');
    }
  }

  // Method to sign out the current user
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    // Navigate to the authentication screen after signing out
    Navigator.pushReplacementNamed(context, '/auth');
  }

  // Widget to build the list of chats
  Widget buildChatList() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          // Show a loading indicator while the data is loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Handle any errors that occur during data fetching
          if (snapshot.hasError) {
            return const Center(child: Text('An error occurred.'));
          }

          // Show a message if no chat data is available
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No chats available.'));
          }

          // Extract chat documents from the snapshot
          var chatDocs = snapshot.data!.docs;

          // Build a list of chat items
          return ListView.builder(
            itemCount: chatDocs.length,
            itemBuilder: (context, index) {
              var chatDoc = chatDocs[index];
              var chatData = chatDoc.data() as Map<String, dynamic>;
              var lastMessage = chatData['lastMessage'] ?? '';
              var participants = chatData['participants'] as List<dynamic>;
              var friendId =
                  participants.firstWhere((id) => id != currentUser!.uid);

              // Fetch friend information using a FutureBuilder
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(friendId)
                    .get(),
                builder: (context, friendSnapshot) {
                  // Show a loading message while the friend data is loading
                  if (friendSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const ListTile(
                      title: Text('Loading...'),
                    );
                  }

                  // Handle any errors that occur while fetching friend data
                  if (friendSnapshot.hasError) {
                    return ListTile(
                      title: Text('Error: ${friendSnapshot.error}'),
                    );
                  }

                  // Show a message if the friend data is not available
                  if (!friendSnapshot.hasData || !friendSnapshot.data!.exists) {
                    return const ListTile(
                      title: Text('User not found'),
                    );
                  }

                  // Extract friend data and display it in the chat list
                  var friendData =
                      friendSnapshot.data!.data() as Map<String, dynamic>;
                  var friendName = friendData['name'] ?? 'Unknown';
                  var friendImage = friendData['image'] ?? '';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: friendImage.isNotEmpty
                          ? NetworkImage(friendImage)
                          : const AssetImage('assets/person.png')
                              as ImageProvider,
                    ),
                    title: Text(friendName),
                    subtitle: Text(lastMessage),
                    onTap: () {
                      // Navigate to the chat page when a chat item is tapped
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatPage(
                            u_id: friendId,
                            currentUserId: currentUser!.uid,
                            userName: friendName,
                            userImage: friendImage,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chats',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryColor,
        actions: [
          // Search button in the app bar
          IconButton(
            icon: const Icon(
              Icons.search,
              color: Colors.white,
            ),
            onPressed: () {
              showSearchDialog(context, currentUser);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          buildChatList(), // Display the chat list
        ],
      ),
    );
  }
}
