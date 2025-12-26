import 'package:flutter/material.dart';
import 'routes/mainRoute.dart'; // ⬅️ router 가져오기
import 'pages/wardrobe/user_wardrobe_list.dart';

void main() {
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
