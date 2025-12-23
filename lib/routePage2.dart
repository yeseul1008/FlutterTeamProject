import 'package:flutter/material.dart';

class Page2 extends StatelessWidget {
  // case3 : page2주소로 이동시 실행 페이지 - 파라미터 포함

  final String name;
  final String age;
  const Page2({super.key, required this.name, required this.age});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title : Text("page2")),
        body : Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("page2", style: TextStyle(fontSize: 30),),
              Text("이름: $name"),
              Text("나이: $age"),
            ],
          ),
        )
    );
  }
}
