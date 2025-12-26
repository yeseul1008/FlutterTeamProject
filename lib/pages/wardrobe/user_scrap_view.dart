import 'package:flutter/material.dart';
import '../../widgets/common/main_btn.dart';
import 'package:go_router/go_router.dart';

class UserScrapView extends StatelessWidget {
  const UserScrapView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body : Center(
          child: Text("여기는 스크랩한 룩북의 상세보기를 보는곳 입니다"),
        )
    );
  }
}
