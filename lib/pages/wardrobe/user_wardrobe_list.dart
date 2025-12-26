import 'package:flutter/material.dart';
import '../../widgets/common/main_btn.dart';
import 'package:go_router/go_router.dart';

class UserWardrobeList extends StatelessWidget {
  const UserWardrobeList({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body : Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MainButton(
                text: '룩북으로 이동',
                onTap: () => context.go('/userLookbook'),
              ),
              const SizedBox(height: 16),
              MainButton(
                text: 'page2으로 이동 (파라미터 전달)',
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
