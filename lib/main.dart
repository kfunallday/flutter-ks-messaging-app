import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added for session listening

import 'ChatScreen.dart';
import 'util/Themes.dart';
// import 'LoginScreen.dart'; // You will need to import your custom login screen here

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const FlutterChatApp());
}

class FlutterChatApp extends StatelessWidget {
  const FlutterChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Ks-messaging", // Updated system title
      theme: defaultTargetPlatform == TargetPlatform.iOS
          ? Themes.kIOSTheme
          : Themes.kDefaultTheme,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. Show a loading spinner while checking the session
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // 2. If the user is logged in, hold them in the ChatScreen
          if (snapshot.hasData) {
            return const ChatScreen();
          }
          // 3. If NOT logged in, route them to your Email/Password Login Screen
          // (Temporarily showing a placeholder until we build the UI)
          return Scaffold(
            appBar: AppBar(title: const Text('Ks-messaging Login')),
            body: const Center(child: Text('Email/Password UI goes here')),
          );
        },
      ),
    );
  }
}