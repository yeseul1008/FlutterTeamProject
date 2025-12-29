import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title : const Center(
          child : Text('✔편의를 위해 시작하는 페이지')
        )
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '이동 필요한 버튼 넣으셔도 될듯요',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                context.go('/userLogin');
              },
              child: const Text('로그인 페이지로 이동'),
            ),
          ],
        ),
      ),
    );
  }
}
