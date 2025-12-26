import 'package:flutter/material.dart';
import '../../widgets/common/main_btn.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DiaryMap extends StatefulWidget {
  const DiaryMap({super.key});

  String? get document => null;


  @override
  State<DiaryMap> createState() => _DiaryMapState();
}

class _DiaryMapState extends State<DiaryMap> {

  final FirebaseFirestore fs = FirebaseFirestore.instance;
  // user ID hardcoding
  String userId = 'tHuRzoBNhPhONwrBeUME';
  String userId2 = 'TEST1';
  Map<String, dynamic> userInfo = {};
  int lookbookCnt = 0;

  Future <void> _getUserInfo () async {

    // 룩복 개수
    final lookbookSnapshot = await fs.collection('lookbooks')
        .where('userId', isEqualTo: userId2)
        .get();

    //사용자 정보
    final userSnapshot = await fs.collection('users').doc(userId).get();

    if(userSnapshot.exists){
      setState(() {
        userInfo = userSnapshot.data()!;
        lookbookCnt = lookbookSnapshot.docs.length;
      });

      print('Lookbooks : $lookbookCnt');

    } else {
      print('User not found');
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getUserInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body : Column(
            children: [
              Container(
                width: double.infinity,
                height: 180,
                color: Colors.black,
                child: Stack(  // Remove SafeArea wrapper
                  children: [
                    Positioned(
                      top: 5,
                      right: 10,
                      child: IconButton(
                        onPressed: () => context.go('/profileEdit'),
                        icon: Icon(
                          Icons.more_horiz,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 15,
                      top: 40,
                      child: CircleAvatar(
                        radius: 40,
                      ),
                    ),
                    Positioned(
                      top: 20,
                      left: 130,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${userInfo['userId'] ?? 'Nickname'} \n@${userInfo['nickname'] ?? 'thisIsmyId'}",
                            style: TextStyle(color: Colors.white),
                          ),
                          SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "0 \nitems",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white),
                              ),
                              SizedBox(width: 20),
                              Text(
                                "$lookbookCnt \nlookbook",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white),
                              ),
                              SizedBox(width: 20),
                              Text(
                                "0 \nAI lookbook",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(150, 35),
                            ),
                            onPressed: () => context.go('/calendarPage'),
                            child: Text(
                              "+ diary",
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
                          backgroundColor: Colors.white,
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
                          backgroundColor: Color(0xFFCAD83B),
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
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search',
                  suffixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  )
                ),
              ),
              SizedBox(
                height: 20,
              ),
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black)
                ),
                child: Center(child: Text('The map is going here')),
              )
            ],
          ),

    );
  }
}
