import 'package:flutter/material.dart';
import '../../widgets/common/main_btn.dart';
import 'package:go_router/go_router.dart';

class UserJoin extends StatelessWidget {
  const UserJoin({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body : Center(
          child: Text("여기는 회원가입 페이지 입니다"),
        )
    );
  }
}
