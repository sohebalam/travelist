import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageTextField extends StatefulWidget {
  final String currentUserId;
  final String friendId;

  const MessageTextField(this.currentUserId, this.friendId, {super.key});

  @override
  _MessageTextFieldState createState() => _MessageTextFieldState();
}

class _MessageTextFieldState extends State<MessageTextField> {
  final TextEditingController _controller = TextEditingController();

  void _sendMessage() {
    if (_controller.text.isEmpty) return;

    String message = _controller.text.trim();
    _controller.clear();

    FirebaseFirestore.instance
        .collection("users")
        .doc(widget.currentUserId)
        .collection('messages')
        .doc(widget.friendId)
        .collection('chats')
        .add({
      'senderId': widget.currentUserId,
      'receiverId': widget.friendId,
      'message': message,
      'date': DateTime.now(),
    });

    FirebaseFirestore.instance
        .collection("users")
        .doc(widget.friendId)
        .collection('messages')
        .doc(widget.currentUserId)
        .collection('chats')
        .add({
      'senderId': widget.currentUserId,
      'receiverId': widget.friendId,
      'message': message,
      'date': DateTime.now(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      color: Colors.grey[200],
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "Type a message...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FloatingActionButton(
            onPressed: _sendMessage,
            backgroundColor: Colors.blue,
            elevation: 0,
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
