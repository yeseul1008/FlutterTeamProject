import 'package:flutter/material.dart';
import '../../widgets/common/main_btn.dart';
import 'package:go_router/go_router.dart';

class CommunityMainFeed extends StatelessWidget {
  const CommunityMainFeed({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body : Center(
          child: Text("여기는 커뮤니티 입니다"),
        )
    );
  }
}
