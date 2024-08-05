// Import necessary packages
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:travelist/services/styles.dart';
import 'package:intl/intl.dart';

// Stateful widget representing the chat page
class ChatPage extends StatefulWidget {
  final String u_id; // Friend's ID
  final String currentUserId; // Current user's ID
  final String userName; // Friend's name
  final String userImage; // Friend's profile image URL

  const ChatPage({
    super.key,
    required this.u_id,
    required this.currentUserId,
    required this.userName,
    required this.userImage,
  });

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController =
      TextEditingController(); // Controller for message input field

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
        title: Row(
          children: [
            // Display user's profile image or a default image if not available
            ClipRRect(
              borderRadius: BorderRadius.circular(80),
              child: widget.userImage.isNotEmpty
                  ? Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          fit: BoxFit.cover,
                          image: CachedNetworkImageProvider(widget.userImage),
                        ),
                      ),
                    )
                  : Image.asset(
                      'assets/person.png', // Local default image path
                      height: 30,
                    ),
            ),
            // Placeholder for when no profile image is available
            if (widget.userImage.isEmpty)
              Container(
                height: 30,
                width: 30,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(80),
                ),
                child: Icon(
                  Icons.person,
                  color: Colors.grey[500],
                ),
              ),
            const SizedBox(width: 10), // Spacing between image and text
            // Display user's name
            Text(
              widget.userName,
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Display chat messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(getChatId(widget.currentUserId, widget.u_id))
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  // Show loading indicator while messages are loading
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                var messages =
                    snapshot.data!.docs; // Fetch messages from Firestore

                return ListView.builder(
                  reverse: true, // Show newest messages at the bottom
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message = messages[index];
                    bool isSentByCurrentUser =
                        message['senderId'] == widget.currentUserId;

                    // Format the timestamp
                    String formattedDate = '';
                    if (message['timestamp'] != null) {
                      var date = (message['timestamp'] as Timestamp).toDate();
                      formattedDate = DateFormat('MMM d, h:mm a').format(date);
                    } else {
                      formattedDate =
                          'Sending...'; // Display if timestamp is not available
                    }

                    return Align(
                      alignment: isSentByCurrentUser
                          ? Alignment.centerRight
                          : Alignment
                              .centerLeft, // Align messages based on sender
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 5, horizontal: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSentByCurrentUser
                              ? Colors.blue
                              : Colors.grey.shade300, // Message bubble color
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: isSentByCurrentUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start, // Text alignment
                          children: [
                            // Display message text
                            Text(
                              message['text'],
                              style: TextStyle(
                                color: isSentByCurrentUser
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 5),
                            // Display formatted timestamp
                            Text(
                              formattedDate,
                              style: TextStyle(
                                color: isSentByCurrentUser
                                    ? Colors.white70
                                    : Colors.black54,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Input field and send button for new messages
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // Text input field
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    // Send message when Enter key is pressed
                    onSubmitted: (text) {
                      sendMessage(text);
                    },
                  ),
                ),
                // Send button
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    sendMessage(_messageController.text);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Function to generate a unique chat ID based on the user IDs
  String getChatId(String userId, String peerId) {
    return userId.hashCode <= peerId.hashCode
        ? '$userId-$peerId'
        : '$peerId-$userId';
  }

  // Function to send a message
  void sendMessage(String text) {
    if (text.isNotEmpty) {
      var chatId = getChatId(widget.currentUserId, widget.u_id);
      var senderId = widget.currentUserId;
      var receiverId = widget.u_id;

      // Add message to Firestore
      FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'text': text,
        'senderId': senderId,
        'receiverId': receiverId,
        'timestamp': FieldValue.serverTimestamp(),
      }).then((value) {
        print("Message sent successfully: $value");
      }).catchError((error) {
        print("Failed to send message: $error");
      });

      _messageController.clear(); // Clear the input field
    }
  }
}
