import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class DirectChatScreen extends StatefulWidget {
  final String peerUid;
  final String peerName;

  const DirectChatScreen({
    super.key,
    required this.peerUid,
    required this.peerName,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _textEditingController = TextEditingController();
  bool _isComposing = false;
  late final String _chatRoomId;
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    // Deterministic chat ID generation (sorted UIDs)
    final ids = [currentUser!.uid, widget.peerUid]..sort();
    _chatRoomId = ids.join('_');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.peerName),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading messages.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == currentUser?.uid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[100] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (data['imageUrl'] != null)
                              Image.network(data['imageUrl'], width: 200, height: 200, fit: BoxFit.cover),
                            if (data['text'] != null && data['text'].toString().isNotEmpty)
                              Text(data['text'], style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    );
                  },
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
          children: [
            IconButton(
              icon: const Icon(Icons.photo_camera),
              onPressed: _sendImageMessage,
            ),
            Flexible(
              child: TextField(
                controller: _textEditingController,
                onChanged: (text) {
                  setState(() {
                    _isComposing = text.trim().isNotEmpty;
                  });
                },
                onSubmitted: _handleSubmitted,
                decoration: const InputDecoration.collapsed(hintText: 'Send a message'),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Theme.of(context).platform == TargetPlatform.iOS
                  ? CupertinoButton(
                      onPressed: _isComposing ? () => _handleSubmitted(_textEditingController.text) : null,
                      child: const Text('Send'),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _isComposing ? () => _handleSubmitted(_textEditingController.text) : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendImageMessage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? imageFile = await picker.pickImage(source: ImageSource.gallery);
    if (imageFile == null) return;

    final random = DateTime.now().millisecondsSinceEpoch;
    final storageRef = FirebaseStorage.instance.ref().child('chat_images/chat_$_chatRoomId\_$random.jpg');

    final uploadTask = storageRef.putFile(File(imageFile.path));
    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    _sendMessage(messageText: null, imageUrl: downloadUrl);
  }

  Future<void> _handleSubmitted(String text) async {
    _textEditingController.clear();
    setState(() => _isComposing = false);
    _sendMessage(messageText: text, imageUrl: null);
  }

  Future<void> _sendMessage({String? messageText, String? imageUrl}) async {
    final chatDocRef = FirebaseFirestore.instance.collection('chats').doc(_chatRoomId);

    // Initialize participants list for security rules
    await chatDocRef.set({
      'participants': [currentUser!.uid, widget.peerUid],
      'lastMessage': messageText ?? 'Sent an image',
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Append message to subcollection
    await chatDocRef.collection('messages').add({
      'text': messageText,
      'imageUrl': imageUrl,
      'senderId': currentUser!.uid,
      'senderEmail': currentUser!.email,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}