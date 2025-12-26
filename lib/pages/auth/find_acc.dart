import 'package:flutter/material.dart';
import '../../widgets/common/main_btn.dart';
import 'package:go_router/go_router.dart';

class FindIdPwd extends StatelessWidget {
  const FindIdPwd({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body : Center(
          child: Text("아이디찾기/비번찾기 입니다."),
        )
    );
  }
}
