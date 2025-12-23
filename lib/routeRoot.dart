import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RootPage extends StatelessWidget {
  // case 1 : 최초 실행 시 루트(/) 페이지
  const RootPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title : Text("RootPage")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => context.go('/page1'),
              child: Text('페이지 1로 이동'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = Uri.encodeComponent('홍길동');
                final age = Uri.encodeComponent('30');
                context.go('/page2?name=$name&age=$age');
              },
              child: Text('페이지 2로 이동(파라미터 전달)'),
            ),
          ],
        ),
      ),
    );
  }
}
