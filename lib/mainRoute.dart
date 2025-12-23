import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'routePage1.dart';
import 'routePage2.dart';
import 'routeRoot.dart';

void main() => runApp(MyApp());

final GoRouter router = GoRouter(
  routes: [
    // case1 : 기본 페이지
    GoRoute(path: '/', builder: (context, state) => RootPage()),
    // case2 : page1주소로 이동시 실행 페이지
    GoRoute(path: '/page1', builder: (context, state) => Page1()),
    // case3 : page2주소로 이동시 실행 페이지 - 파라미터 포함
    GoRoute(path: '/page2', builder: (context, state) {
      String name = state.uri.queryParameters['name'] ?? '이름 없음';
      String age = state.uri.queryParameters['age'] ?? '나이 없음';
      return Page2(name: name, age: age);
    }),
  ],
);

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
    );
  }
}
