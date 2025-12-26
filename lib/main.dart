import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'routes/mainRoute.dart'; // ⬅️ router 가져오기
import 'pages/wardrobe/user_wardrobe_list.dart';
import 'firebase/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Firebase 초기화 설정
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router, // ⭐ 이 router가 실행된다
    );
  }
}