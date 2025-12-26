import 'package:flutter/material.dart';
import '../../widgets/common/main_btn.dart';
import 'package:go_router/go_router.dart';

class QuestionFeed extends StatelessWidget {
  const QuestionFeed({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body : Center(
          child: Text("여기는 qna feed 입니다"),
        )
    );
  }
}
