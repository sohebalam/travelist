import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  final String u_id; // This should be the friend's ID
  final String currentUserId;

  const ChatPage({super.key, required this.u_id, required this.currentUserId});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: Column(
        children: [
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
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                var messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message = messages[index];
                    bool isSentByCurrentUser =
                        message['senderId'] == widget.currentUserId;

                    return Align(
                      alignment: isSentByCurrentUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin:
                            const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSentByCurrentUser
                              ? Colors.blue
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: isSentByCurrentUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              message['text'],
                              style: TextStyle(
                                color: isSentByCurrentUser
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              message['timestamp'] != null
                                  ? (message['timestamp'] as Timestamp)
                                      .toDate()
                                      .toLocal()
                                      .toString()
                                  : 'Sending...',
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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onSubmitted: (text) {
                      sendMessage(text);
                    },
                  ),
                ),
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

  String getChatId(String userId, String peerId) {
    return userId.hashCode <= peerId.hashCode
        ? '$userId-$peerId'
        : '$peerId-$userId';
  }

  void sendMessage(String text) {
    if (text.isNotEmpty) {
      var chatId = getChatId(widget.currentUserId, widget.u_id);
      var senderId = widget.currentUserId;
      var receiverId = widget.u_id;

      // Debug prints to check values
      print('Chat ID: $chatId');
      print('Sender ID: $senderId');
      print('Receiver ID: $receiverId');
      print('Message Text: $text');

      FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'text': text,
        'senderId': senderId,
        'receiverId': receiverId, // Ensure receiverId is set correctly
        'timestamp': FieldValue.serverTimestamp(),
      }).then((value) {
        print("Message sent successfully: $value");
      }).catchError((error) {
        print("Failed to send message: $error");
      });

      _messageController.clear();
    }
  }
}
