import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'DirectChatScreen.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ks-messaging'),
        elevation: Theme.of(context).platform == TargetPlatform.iOS ? 0.0 : 4.0,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading users.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final otherUsers = docs.where((doc) => doc.id != currentUser?.uid).toList();

          if (otherUsers.isEmpty) {
            return const Center(child: Text('No other users found.'));
          }

          return ListView.builder(
            itemCount: otherUsers.length,
            itemBuilder: (context, index) {
              final userData = otherUsers[index].data() as Map<String, dynamic>;
              final peerUid = userData['uid'] ?? '';
              final peerName = userData['displayName'] ?? 'User';
              final peerEmail = userData['email'] ?? '';

              return ListTile(
                leading: CircleAvatar(
                  child: Text(peerName.isNotEmpty ? peerName[0].toUpperCase() : 'U'),
                ),
                title: Text(peerName),
                subtitle: Text(peerEmail),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DirectChatScreen(
                        peerUid: peerUid,
                        peerName: peerName,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}