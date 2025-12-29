import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../firebase/firestore_service.dart';

class GoogleLogin extends StatelessWidget {
  const GoogleLogin({super.key});

  get GoogleAuthService => null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            try {
              final result =
              await GoogleAuthService.signInWithGoogle();

              if (result == null) return;

              context.go('/'); // 홈
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('구글 로그인 실패')),
              );
            }
          },
          child: const Text('Google로 시작하기'),
        ),
      ),
    );
  }
}
