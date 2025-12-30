import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'routes/mainRoute.dart'; // router
import 'firebase/firebase_options.dart'; //

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env 로드 (파일이 루트에 있고 pubspec.yaml assets에 등록돼 있어야 함)
  await dotenv.load(fileName: ".env");

  // Firebase 초기화 (반드시 runApp 전에)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
