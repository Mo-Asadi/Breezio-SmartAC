import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:breezio/screens/splash_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart AC',
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}