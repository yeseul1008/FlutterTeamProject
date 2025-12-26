import 'package:flutter/material.dart';
import '../../widgets/common/main_btn.dart';
import 'package:go_router/go_router.dart';

class UserWardrobeCategory extends StatelessWidget {
  const UserWardrobeCategory({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body : Center(
          child: Text("여기는 옷장 카테고리를 보는 공간 입니다"),
        )
    );
  }
}
