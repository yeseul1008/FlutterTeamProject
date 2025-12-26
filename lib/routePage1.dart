import 'package:flutter/material.dart';

class Page1 extends StatelessWidget {
  // case2 : /page1 주소로 이동 시 실행 페이지
  const Page1({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title : Text("page1")),
      body : Center(
        child: Text("page1"),
      )
    );
  }
}
