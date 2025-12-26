import 'package:flutter/material.dart';
import '../../widgets/common/main_btn.dart';
import 'package:go_router/go_router.dart';

class AiOutfitMaker extends StatelessWidget {
  const AiOutfitMaker({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body : Center(
          child: Text("여기는 ai가 코디만들어주는곳 입니다"),
        )
    );
  }
}
