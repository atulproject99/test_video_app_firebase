import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:test_video_app_firebase/call_page.dart';
import 'package:test_video_app_firebase/firebase_options.dart';

void main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(Colors.deepPurpleAccent),
            foregroundColor: WidgetStatePropertyAll(Colors.white),
          ),
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: CallPage(),
    );
  }
}
