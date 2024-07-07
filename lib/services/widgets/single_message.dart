import 'package:flutter/material.dart';
import 'package:travelist/services/styles.dart';

class SingleMessage extends StatelessWidget {
  final String message;
  final bool isMe;
  final String friendName;
  final String datetime;

  const SingleMessage({super.key, 
    required this.message,
    required this.isMe,
    required this.friendName,
    required this.datetime,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            isMe ? 'You' : friendName,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isMe
                    ? Theme.of(context).colorScheme.secondary
                    : AppColors.quateraryColor),
          ),
          const SizedBox(height: 4.0),
          Text(
            message,
            style: TextStyle(
              color: isMe ? Colors.blue : Colors.black,
            ),
          ),
          const SizedBox(height: 3.0),
          Text(
            datetime,
            style: TextStyle(
              fontSize: 10.0,
              color: isMe ? Colors.blue : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
