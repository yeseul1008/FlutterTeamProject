import 'package:flutter/material.dart';
import '../../widgets/common/main_btn.dart';
import 'package:go_router/go_router.dart';

class FollowList extends StatelessWidget {
  const FollowList({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body : Center(
          child: Text("여기는 팔로우리스트 입니다."),
        )
    );
  }
}
