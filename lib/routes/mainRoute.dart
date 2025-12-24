import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routePage1.dart';
import '../routePage2.dart';
import '/pages/auth/user_login.dart';

// 앱 시작점
void main() => runApp(const MyApp());

final GoRouter router = GoRouter(
  routes: [
    // 시작 페이지 → 로그인
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginScreen(),
    ),

    // page1
    GoRoute(
      path: '/page1',
      builder: (context, state) => const Page1(),
    ),

    // page2 (쿼리 파라미터)
    GoRoute(
      path: '/page2',
      builder: (context, state) {
        final name = state.uri.queryParameters['name'] ?? '이름 없음';
        final age = state.uri.queryParameters['age'] ?? '나이 없음';
        return Page2(name: name, age: age);
      },
    ),
  ],
);

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
