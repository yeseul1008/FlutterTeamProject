import 'package:flutter/material.dart';
import '../../widgets/common/main_btn.dart';
import 'package:go_router/go_router.dart';

class DiaryMap extends StatelessWidget {
  const DiaryMap({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body : Center(
          child: Text("여기는 다이어리 - 지도 입니다"),
        )
    );
  }
}
