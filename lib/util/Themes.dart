import 'package:flutter/material.dart';

class Themes {
  static final ThemeData kIOSTheme = ThemeData(
    primarySwatch: Colors.orange,
    primaryColor: Colors.grey[100],
    colorScheme: ColorScheme.light(
      primary: Colors.grey[100]!,
      secondary: Colors.orangeAccent,
    ),
  );

  static final ThemeData kDefaultTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.purple,
      primary: Colors.purple,
      secondary: Colors.blue[400]!,
    ),
  );
}