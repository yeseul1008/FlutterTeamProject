import 'package:flutter/material.dart';
import '../../widgets/common/main_btn.dart';
import 'package:go_router/go_router.dart';

class PublicWardrobe extends StatelessWidget {
  const PublicWardrobe({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body : Center(
          child: Text("여기는 다른유저의 옷장 입니다"),
        )
    );
  }
}
