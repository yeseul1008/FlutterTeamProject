import 'package:flutter/material.dart';
import '../../widgets/common/main_btn.dart';
import 'package:go_router/go_router.dart';

class QuestionAdd extends StatelessWidget {
  const QuestionAdd({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body : Center(
          child: Text("여기는 질문추가 입니다"),
        )
    );
  }
}
