import 'package:flutter/material.dart';
import '../../widgets/common/main_btn.dart';
import 'package:go_router/go_router.dart';

class UserDiaryCards extends StatelessWidget {
  const UserDiaryCards({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body : Center(
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.black,
                    ),
                  ),
                  Positioned( // 개인 정보 수정 버튼
                      top : 5,
                      right: 10,
                      child: IconButton(
                          onPressed: () => context.go('/profileEdit'),
                          icon: Icon(
                            Icons.more_horiz,
                            color: Colors.white,
                            size: 40,
                          )
                      )
                  ),
                  Positioned( // 사용자 사진
                      left: 15,
                      top: 40,
                      child: CircleAvatar(
                        radius: 40,
                      )
                  ),
                  Positioned( // 사용자 개인 정보
                    top: 20,
                    left: 130,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Nickname \n@thisIsmyId",
                            style: TextStyle(
                              color: Colors.white
                            ),
                          ),
                          SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                  "0 \nitems",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.white
                                  ),
                              ),
                              SizedBox(width: 20),
                              Text(
                                  "0 \nlookbook",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.white
                                  ),
                              ),
                              SizedBox(width: 20),
                              Text(
                                  "0 \nAI lookbook",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.white
                                  ),
                              )
                            ],
                          ),
                          SizedBox(
                            height: 10
                            ,
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(150, 35)
                            ),
                              onPressed: () => context.go('/calendarPage'),
                              child:
                              Text(
                                  "+ diary",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                              )
                          )
                        ],
                      )
                  ),
                ],
              ),
              SizedBox(
                height: 10,
              ),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50, // ⭐ 버튼 높이 증가
                      child: ElevatedButton(
                        onPressed: () => context.go('/userDiaryCards'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFCAD83B),
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: EdgeInsets.zero, // 높이 정확히 맞춤
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                            side: const BorderSide(color: Colors.black),
                          ),
                        ),
                        child: const Text(
                          'diary',
                          style: TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => context.go('/diaryMap'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                            side: const BorderSide(color: Colors.black),
                          ),
                        ),
                        child: const Text(
                          'map',
                          style: TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 20,
              ),
              Expanded(
                child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:  3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.8,
                      ),
                    itemCount: 6,
                    itemBuilder: (context, index){
                      return Card(
                        child: Column(
                          children: [
                            Expanded(child: Container())
                          ],
                        ),
                      );
                    }
                ),
              )
            ],
          ),
        )
    );
  }
}
