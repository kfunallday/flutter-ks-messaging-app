import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

import 'ChatMessageListItem.dart';

final googleSignIn = GoogleSignIn();
final analytics = FirebaseAnalytics.instance;
final auth = FirebaseAuth.instance;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textEditingController = TextEditingController();
  bool _isComposing = false;
  final DatabaseReference _messageRef =
      FirebaseDatabase.instance.ref().child('messages');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ks-messaging'),
        elevation: Theme.of(context).platform == TargetPlatform.iOS ? 0.0 : 4.0,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _signOut,
          )
        ],
      ),
      body: Column(
        children: <Widget>[
          Flexible(
            child: FirebaseAnimatedList(
              query: _messageRef,
              sort: (a, b) {
                final aKey = a.key ?? '';
                final bKey = b.key ?? '';
                return bKey.compareTo(aKey);
              },
              itemBuilder: (BuildContext context, DataSnapshot messageSnapshot,
                  Animation<double> animation, int index) {
                return ChatMessageListItem(
                  messageSnapshot: messageSnapshot,
                  animation: animation,
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(color: Theme.of(context).cardColor),
            child: _buildTextComposer(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextComposer() {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.photo_camera),
              onPressed: () async {
                await _ensureLoggedIn();
                final ImagePicker picker = ImagePicker();
                final XFile? imageFile =
                    await picker.pickImage(source: ImageSource.gallery);
                if (imageFile == null) return;

                int random = DateTime.now().millisecondsSinceEpoch;
                Reference storageReference = FirebaseStorage.instance
                    .ref()
                    .child('chat_image_$random.jpg');
                UploadTask uploadTask =
                    storageReference.putFile(File(imageFile.path));
                TaskSnapshot snapshot = await uploadTask;
                String downloadUrl = await snapshot.ref.getDownloadURL();
                _sendMessage(messageText: null, imageUrl: downloadUrl);
              },
            ),
            Flexible(
              child: TextField(
                controller: _textEditingController,
                onChanged: (String text) {
                  setState(() {
                    _isComposing = text.trim().isNotEmpty;
                  });
                },
                onSubmitted: _handleSubmitted,
                decoration:
                    const InputDecoration.collapsed(hintText: 'Send a message'),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Theme.of(context).platform == TargetPlatform.iOS
                  ? CupertinoButton(
                      child: const Text('Send'),
                      onPressed: _isComposing
                          ? () => _handleSubmitted(_textEditingController.text)
                          : null,
                    )
                  : IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _isComposing
                          ? () => _handleSubmitted(_textEditingController.text)
                          : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmitted(String text) async {
    _textEditingController.clear();
    setState(() {
      _isComposing = false;
    });
    await _ensureLoggedIn();
    _sendMessage(messageText: text, imageUrl: null);
  }

  void _sendMessage({String? messageText, String? imageUrl}) {
    final currentUser = googleSignIn.currentUser;
    _messageRef.push().set({
      'text': messageText,
      'email': currentUser?.email,
      'imageUrl': imageUrl,
      'senderName': currentUser?.displayName,
      'senderPhotoUrl': currentUser?.photoUrl,
    });
    analytics.logEvent(name: 'send_message');
  }

  Future<void> _ensureLoggedIn() async {
    GoogleSignInAccount? user = googleSignIn.currentUser ??
        await googleSignIn.signInSilently() ??
        await googleSignIn.signIn();

    if (user != null && auth.currentUser == null) {
      final GoogleSignInAuthentication googleAuth = await user.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await auth.signInWithCredential(credential);
    }
  }

  Future<void> _signOut() async {
    await googleSignIn.signOut();
    await auth.signOut();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User logged out')),
      );
    }
  }
}