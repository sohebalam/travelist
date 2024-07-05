import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:travelist/services/styles.dart';
import 'package:travelist/services/widgets/message_textfield.dart';
import 'package:travelist/services/widgets/single_message.dart';

class ChatPage extends StatefulWidget {
  final String u_id;
  final String currentUserId;

  const ChatPage({Key? key, required this.u_id, required this.currentUserId})
      : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  String _otherUserName = '';
  String _otherUserImage = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      DocumentSnapshot documentSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.u_id)
          .get();
      if (documentSnapshot.exists) {
        setState(() {
          _otherUserName = documentSnapshot.get('name') ?? '';
          _otherUserImage = documentSnapshot.get('image') ?? '';
        });
      } else {
        print('User does not exist in the database');
      }
    } catch (error) {
      print('Error retrieving user data: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(80),
              child: _otherUserImage.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: _otherUserImage,
                      width: 30,
                      height: 30,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          CircularProgressIndicator(),
                      errorWidget: (context, url, error) => Icon(Icons.error),
                    )
                  : Image.asset(
                      'assets/person.png',
                      height: 30,
                      width: 30,
                    ),
            ),
            SizedBox(width: 5),
            Text(_otherUserName, style: TextStyle(fontSize: 20)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25)),
              ),
              child: StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection("users")
                    .doc(widget.currentUserId)
                    .collection('messages')
                    .doc(widget.u_id)
                    .collection('chats')
                    .orderBy("date", descending: true)
                    .snapshots(),
                builder: (context, AsyncSnapshot snapshot) {
                  if (snapshot.hasData) {
                    if (snapshot.data.docs.isEmpty) {
                      return Center(child: Text("Say Hi"));
                    }
                    return ListView.builder(
                      itemCount: snapshot.data.docs.length,
                      reverse: true,
                      physics: BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        bool isMe = snapshot.data.docs[index]['senderId'] ==
                            widget.currentUserId;
                        DateTime date =
                            snapshot.data.docs[index]['date'].toDate();
                        String datetime =
                            DateFormat('MMM d, h:mm a').format(date);
                        String message = snapshot.data.docs[index]['message'];
                        return SingleMessage(
                          friendName: _otherUserName,
                          datetime: datetime,
                          message: message,
                          isMe: isMe,
                        );
                      },
                    );
                  }
                  return Center(child: CircularProgressIndicator());
                },
              ),
            ),
          ),
          MessageTextField(widget.currentUserId, widget.u_id),
        ],
      ),
    );
  }
}
