import 'package:flutter/material.dart';
import '../../widgets/common/main_btn.dart';
import 'package:go_router/go_router.dart';

class UserWardrobeAdd extends StatelessWidget {
  const UserWardrobeAdd({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body : Center(
          child: Text("여기는 옷장에 옷을 추가하는 페이지 입니다"),
        )
    );
  }
}
