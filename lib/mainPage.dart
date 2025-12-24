import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common/main_btn.dart';
import '../widgets/common/bottom_nav_bar.dart';

// main실행 시 최초 실행되는페이지
class RootPage extends StatelessWidget {
  const RootPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MainButton(
              text: '페이지 1로 이동',
              onTap: () => context.go('/page1'),
            ),
            const SizedBox(height: 16),
            MainButton(
              text: '페이지 2로 이동 (파라미터 전달)',
              onTap: () {
                final name = Uri.encodeComponent('홍길동');
                final age = Uri.encodeComponent('30');
                context.go('/page2?name=$name&age=$age');
              },
            ),
          ],
        ),
      ),
    );
  }
}
