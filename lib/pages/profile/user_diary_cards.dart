import 'package:flutter/material.dart';
import '../../widgets/common/main_btn.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class UserDiaryCards extends StatefulWidget {
  const UserDiaryCards({super.key});

  String? get document => null;

  @override
  State<UserDiaryCards> createState() => _UserDiaryCardsState();
}

class _UserDiaryCardsState extends State<UserDiaryCards> {

  final FirebaseFirestore fs = FirebaseFirestore.instance;
  // user ID hardcoding
  String userId = 'tHuRzoBNhPhONwrBeUME';
  String userId2 = 'TEST1';
  Map<String, dynamic> userInfo = {};
  List<Map<String, dynamic>> userLookbook = [];
  int lookbookCnt = 0;

  // Date Format Function

  String formatKoreanDate(Timestamp? timestamp) {
    if (timestamp == null) return '날짜 없음';

    DateTime dateTime = timestamp.toDate();
    return '${dateTime.year}년 ${dateTime.month}월 ${dateTime.day}일';
  }

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
        userLookbook = lookbookSnapshot.docs.map((doc) {
          final data = doc.data();
          data['formattedDate'] = formatKoreanDate(data['createdAt']);
          return data;
        }).toList();
      });

      print('Lookbooks number : $lookbookCnt, Lookbooks info : $userLookbook');

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

  // Lookbook Dialog Function

  void _LookbookDialog(BuildContext context, int index) {

    if (userLookbook.isEmpty) {
      print('No lookbook data loaded yet');
      return;
    }

    // Image HARDCODING first
    String imageUrl = 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=600';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // aligning on the left
                    children: [
                      // Header
                      Row(
                        children: [
                          Icon(Icons.cloud, size : 20),
                          SizedBox(width: 5),
                          Text("20C"),
                        ],
                      ),
                      SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.location_on, size : 20),
                          SizedBox(width: 5),
                          Text("서울"),
                        ],
                      ),
                      SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size : 20),
                          SizedBox(width: 5),
                          Text("${userLookbook[0]['formattedDate'] ?? 'No date'}",),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Image
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 300,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 300,
                            color: Colors.grey[300],
                            child: Icon(Icons.image_not_supported, size: 80),
                          );
                        },
                      ),

                      // Text area
                      Padding(
                        padding: EdgeInsets.all(16),
                        child:
                        Center(
                          child: Text(
                            '${userLookbook[0]['alias'] ?? "No description"}',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(Icons.edit),
                onPressed: (){},
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override

  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Custom AppBar
          Container(
            width: double.infinity,
            height: 180,
            color: Colors.black,
            child: Stack(
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
          SizedBox(height: 10),
          // Buttons Row - ⭐ Added Padding to make them visible
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => context.go('/userDiaryCards'),
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
                        'diary',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(16), // ⭐ Added padding to grid
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              itemCount: 6,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: (){
                    _LookbookDialog(context, index);
                  },
                  child: Card(
                    child: Column(
                      children: [
                        Expanded(child: Container(child: Center(child: Text("Click me !")),)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
