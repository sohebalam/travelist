import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:travelist/services/styles.dart';
import 'package:travelist/services/widgets/search_dialog.dart';
import 'chat_page.dart';

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
    currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/auth');
      });
    } else {
      print('Current user ID: ${currentUser!.uid}');
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/auth');
  }

  Widget buildChatList() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('An error occurred.'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No chats available.'));
          }

          var chatDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: chatDocs.length,
            itemBuilder: (context, index) {
              var chatDoc = chatDocs[index];
              var chatData = chatDoc.data() as Map<String, dynamic>;
              var lastMessage = chatData['lastMessage'] ?? '';
              var participants = chatData['participants'] as List<dynamic>;
              var friendId =
                  participants.firstWhere((id) => id != currentUser!.uid);

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(friendId)
                    .get(),
                builder: (context, friendSnapshot) {
                  if (friendSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const ListTile(
                      title: Text('Loading...'),
                    );
                  }

                  if (friendSnapshot.hasError) {
                    return ListTile(
                      title: Text('Error: ${friendSnapshot.error}'),
                    );
                  }

                  if (!friendSnapshot.hasData || !friendSnapshot.data!.exists) {
                    return const ListTile(
                      title: Text('User not found'),
                    );
                  }

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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatPage(
                            u_id: friendId,
                            currentUserId: currentUser!.uid,
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
        title: const Text('Chats'),
        backgroundColor: AppColors.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearchDialog(context, currentUser);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          buildChatList(),
        ],
      ),
    );
  }
}
