import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'ChatScreen.dart';
import 'login_screen.dart';
import 'util/Themes.dart';

// Top-level background message handler required by FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Register background FCM handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const FlutterChatApp());
}

class FlutterChatApp extends StatelessWidget {
  const FlutterChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Ks-messaging",
      theme: defaultTargetPlatform == TargetPlatform.iOS
          ? Themes.kIOSTheme
          : Themes.kDefaultTheme,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. Show a loading spinner while checking authentication state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // 2. If the user is logged in, initialize FCM permissions and render ChatScreen
          if (snapshot.hasData) {
            _setupFCM(snapshot.data!);
            return const ChatScreen();
          }
          // 3. If NOT logged in, route to the LoginScreen
          return const LoginScreen();
        },
      ),
    );
  }

  // Silent native FCM setup when authenticated
  Future<void> _setupFCM(User user) async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request native OS notification permissions
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await messaging.getToken();
      if (token != null) {
        // Save the FCM device token to the user document in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
      }
    }
  }
}