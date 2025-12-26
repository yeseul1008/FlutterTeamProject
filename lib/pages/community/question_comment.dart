import 'package:flutter/material.dart';
import '../../widgets/common/main_btn.dart';
import 'package:go_router/go_router.dart';

class QuestionComment extends StatelessWidget {
  const QuestionComment({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body : Center(
          child: Text("여기는 qna 댓글창 입니다"),
        )
    );
  }
}
