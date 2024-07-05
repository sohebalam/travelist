import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:travelist/pages/chat/chat_page.dart';
import 'package:travelist/services/styles.dart';

class ChatList extends StatefulWidget {
  @override
  _ChatListState createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  User? currentUser;
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      Navigator.pushReplacementNamed(context, '/auth');
    } else {
      print('Current user ID: ${currentUser!.uid}');
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/auth');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chats'),
        backgroundColor: AppColors.primaryColor,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser!.uid)
                  .collection('messages')
                  .doc(currentUser!.uid)
                  .collection('chats')
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  print('Snapshot has no data.');
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.data!.docs.isEmpty) {
                  print('No chats available');
                  return Center(child: Text('No chats available.'));
                }

                print("Fetched ${snapshot.data!.docs.length} chat(s)");

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var chat = snapshot.data!.docs[index];
                    var chatData = chat.data() as Map<String, dynamic>?;

                    // Debugging: Print the entire chat document
                    print('Chat document data: ${chatData}');

                    if (chatData == null ||
                        !chatData.containsKey('senderId') ||
                        !chatData.containsKey('receiverId')) {
                      print('Invalid chat data for chat with ID: ${chat.id}');
                      return ListTile(
                        title: Text('Invalid chat data'),
                        subtitle: Text('Required fields are missing.'),
                      );
                    }

                    var friendId = chatData['senderId'] == currentUser!.uid
                        ? chatData['receiverId']
                        : chatData['senderId'];

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(friendId)
                          .get(),
                      builder: (context, friendSnapshot) {
                        if (!friendSnapshot.hasData) {
                          return ListTile(
                            title: Text('Loading...'),
                          );
                        }

                        var friendData = friendSnapshot.data!.data()
                            as Map<String, dynamic>?;
                        if (friendData == null) {
                          print('User not found for friend ID: $friendId');
                          return ListTile(
                            title: Text('User not found'),
                          );
                        }

                        var friendName = friendData['name'] ?? 'Unknown';
                        var friendImage = friendData['image'] ?? '';
                        var lastMessage = chatData['message'] ?? '';

                        print(
                            "Chat with $friendName ($friendId): $lastMessage");

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: friendImage.isNotEmpty
                                ? NetworkImage(friendImage)
                                : AssetImage('assets/person.png')
                                    as ImageProvider,
                          ),
                          title: Text(friendName),
                          subtitle: Text(lastMessage),
                          onTap: () {
                            print(
                                'Navigating to chat with $friendName ($friendId)');
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
          ),
        ],
      ),
    );
  }
}
