import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'ChatScreen.dart';
import 'util/Themes.dart';

void main() async {
  // Binds native platform channels before async operations run
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initializes Firebase SDK before rendering UI
  await Firebase.initializeApp();

  runApp(const FlutterChatApp());
}

class FlutterChatApp extends StatelessWidget {
  const FlutterChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Flutter Chat App",
      theme: defaultTargetPlatform == TargetPlatform.iOS
          ? Themes.kIOSTheme
          : Themes.kDefaultTheme,
      home: const ChatScreen(),
    );
  }
}