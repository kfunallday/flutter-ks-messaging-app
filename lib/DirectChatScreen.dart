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
  final ValueNotifier<bool> _isComposing = ValueNotifier<bool>(false);
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
  void dispose() {
    _textEditingController.dispose();
    _isComposing.dispose();
    super.dispose();
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
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Image.network(
                                  data['imageUrl'],
                                  width: 200,
                                  height: 200,
                                  fit: BoxFit.cover,
                                ),
                              ),
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
                  _isComposing.value = text.trim().isNotEmpty;
                },
                onSubmitted: _handleSubmitted,
                decoration: const InputDecoration.collapsed(hintText: 'Send a message'),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _isComposing,
              builder: (context, isComposing, child) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Theme.of(context).platform == TargetPlatform.iOS
                      ? CupertinoButton(
                          onPressed: isComposing ? () => _handleSubmitted(_textEditingController.text) : null,
                          child: const Text('Send'),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: isComposing ? () => _handleSubmitted(_textEditingController.text) : null,
                        ),
                );
              },
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

    final File file = File(imageFile.path);
    final int fileSize = await file.length();

    // Check user quota before uploading
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(currentUser!.uid);
    final userDoc = await userDocRef.get();

    bool isSenderOverQuota = false;
    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;
      final int currentUsed = userData['bytesUsed'] ?? 0;
      final int quota = userData['storageQuotaBytes'] ?? 262144000;

      if (currentUsed + fileSize > quota) {
        isSenderOverQuota = true;
      }
    }

    final random = DateTime.now().millisecondsSinceEpoch;
    final storageRef = FirebaseStorage.instance.ref().child('chat_images/chat_${_chatRoomId}_$random.jpg');

    try {
      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (!isSenderOverQuota) {
        // Update used bytes in Firestore for sender
        await userDocRef.update({
          'bytesUsed': FieldValue.increment(fileSize),
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage quota exceeded. Image delivered to recipient, but not saved in your cloud backup.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }

      _sendMessageDecoupled(messageText: null, imageUrl: downloadUrl, isSenderOverQuota: isSenderOverQuota);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image upload failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleSubmitted(String text) async {
    _textEditingController.clear();
    _isComposing.value = false;

    // Check sender quota status
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(currentUser!.uid);
    final userDoc = await userDocRef.get();
    bool isSenderOverQuota = false;

    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;
      final int currentUsed = userData['bytesUsed'] ?? 0;
      final int quota = userData['storageQuotaBytes'] ?? 262144000;
      isSenderOverQuota = currentUsed >= quota;
    }

    _sendMessageDecoupled(messageText: text, imageUrl: null, isSenderOverQuota: isSenderOverQuota);
  }

  Future<void> _sendMessageDecoupled({
    String? messageText,
    String? imageUrl,
    required bool isSenderOverQuota,
  }) async {
    final messageData = {
      'text': messageText,
      'imageUrl': imageUrl,
      'senderId': currentUser!.uid,
      'senderEmail': currentUser!.email,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // 1. Shared/Recipient Direct Chat Stream
    final chatDocRef = FirebaseFirestore.instance.collection('chats').doc(_chatRoomId);

    await chatDocRef.set({
      'participants': [currentUser!.uid, widget.peerUid],
      'lastMessage': messageText ?? 'Sent an image',
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await chatDocRef.collection('messages').add(messageData);

    // 2. Recipient Dedicated Cloud Inbox Delivery (Always succeeds regardless of sender quota)
    final recipientInboxRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.peerUid)
        .collection('inbox')
        .doc(_chatRoomId);

    await recipientInboxRef.set({
      'lastMessage': messageText ?? 'Sent an image',
      'lastUpdated': FieldValue.serverTimestamp(),
      'fromUid': currentUser!.uid,
    }, SetOptions(merge: true));

    await recipientInboxRef.collection('messages').add(messageData);

    // 3. Sender Cloud Backup (Saves only if under quota; skipped/purged if over quota)
    if (!isSenderOverQuota) {
      final senderInboxRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('inbox')
          .doc(_chatRoomId);

      await senderInboxRef.set({
        'lastMessage': messageText ?? 'Sent an image',
        'lastUpdated': FieldValue.serverTimestamp(),
        'toUid': widget.peerUid,
      }, SetOptions(merge: true));

      await senderInboxRef.collection('messages').add(messageData);
    }
  }
}