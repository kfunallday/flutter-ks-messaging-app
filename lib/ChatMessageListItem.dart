import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class ChatMessageListItem extends StatelessWidget {
  final DataSnapshot messageSnapshot;
  final Animation<double> animation;

  const ChatMessageListItem({
    super.key,
    required this.messageSnapshot,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email;
    final map = messageSnapshot.value as Map<dynamic, dynamic>? ?? {};

    final String? email = map['email'] as String?;
    final String senderName = (map['senderName'] as String?) ?? 'Anonymous';
    final String? imageUrl = map['imageUrl'] as String?;
    final String? text = map['text'] as String?;
    final String? senderPhotoUrl = map['senderPhotoUrl'] as String?;

    final bool isSentByMe = currentUserEmail != null && currentUserEmail == email;

    return SizeTransition(
      sizeFactor: CurvedAnimation(
        parent: animation,
        curve: Curves.decelerate,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: isSentByMe
              ? getSentMessageLayout(senderName, text, imageUrl, senderPhotoUrl)
              : getReceivedMessageLayout(senderName, text, imageUrl, senderPhotoUrl),
        ),
      ),
    );
  }

  List<Widget> getSentMessageLayout(
    String senderName,
    String? text,
    String? imageUrl,
    String? senderPhotoUrl,
  ) {
    return <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              senderName,
              style: const TextStyle(
                fontSize: 14.0,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 5.0),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 250.0,
                    )
                  : Text(text ?? ''),
            ),
          ],
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(left: 8.0),
            child: CircleAvatar(
              backgroundImage: senderPhotoUrl != null && senderPhotoUrl.isNotEmpty
                  ? NetworkImage(senderPhotoUrl)
                  : null,
              child: senderPhotoUrl == null || senderPhotoUrl.isEmpty
                  ? Text(senderName.isNotEmpty ? senderName[0].toUpperCase() : '?')
                  : null,
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> getReceivedMessageLayout(
    String senderName,
    String? text,
    String? imageUrl,
    String? senderPhotoUrl,
  ) {
    return <Widget>[
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 8.0),
            child: CircleAvatar(
              backgroundImage: senderPhotoUrl != null && senderPhotoUrl.isNotEmpty
                  ? NetworkImage(senderPhotoUrl)
                  : null,
              child: senderPhotoUrl == null || senderPhotoUrl.isEmpty
                  ? Text(senderName.isNotEmpty ? senderName[0].toUpperCase() : '?')
                  : null,
            ),
          ),
        ],
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              senderName,
              style: const TextStyle(
                fontSize: 14.0,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 5.0),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 250.0,
                    )
                  : Text(text ?? ''),
            ),
          ],
        ),
      ),
    ];
  }
}