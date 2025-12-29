import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserDiaryCards extends StatefulWidget {
  const UserDiaryCards({super.key});

  @override
  State<UserDiaryCards> createState() => _UserDiaryCardsState();
}

class _UserDiaryCardsState extends State<UserDiaryCards> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  Map<String, dynamic> userInfo = {};
  List<Map<String, dynamic>> userLookbook = [];
  int lookbookCnt = 0;

  String formatKoreanDate(Timestamp? timestamp) {
    if (timestamp == null) return '날짜 없음';
    final dt = timestamp.toDate();
    return '${dt.year}년 ${dt.month}월 ${dt.day}일';
  }

  Future<void> _getUserInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      if (!mounted) return;
      context.go('/userLogin');
      return;
    }

    final lookbookSnapshot = await fs
        .collection('lookbooks')
        .where('userId', isEqualTo: uid)
        .get();

    final userSnapshot = await fs.collection('users').doc(uid).get();

    if (!mounted) return;
    setState(() {
      userInfo = userSnapshot.data() ?? {'userId': uid};
      lookbookCnt = lookbookSnapshot.docs.length;
      userLookbook = lookbookSnapshot.docs.map((doc) {
        final data = doc.data();
        data['lookbookId'] = doc.id;
        data['formattedDate'] = formatKoreanDate(data['createdAt']);
        return data;
      }).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    _getUserInfo();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      context.go('/userLogin');
    } catch (e) {
      _showSnack('로그아웃 실패: $e');
    }
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    if (user == null || uid == null) {
      _showSnack('로그인 상태가 아닙니다.');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('탈퇴'),
        content: const Text('정말 탈퇴하시겠습니까?\n(계정/데이터가 삭제될 수 있습니다)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await fs.collection('users').doc(uid).delete();
      await user.delete();

      if (!mounted) return;
      context.go('/userLogin');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showSnack('보안을 위해 다시 로그인 후 탈퇴를 진행해주세요.');
      } else {
        _showSnack('탈퇴 실패: ${e.code}');
      }
    } catch (e) {
      _showSnack('탈퇴 실패: $e');
    }
  }

  void _openMoreMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.star_border),
                title: const Text('구독하기'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSnack('구독하기는 준비 중입니다.');
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('로그아웃'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _logout();
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_off_outlined),
                title: const Text('탈퇴'),
                textColor: Colors.red,
                iconColor: Colors.red,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _deleteAccount();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _lookbookDialog(BuildContext context, int index) {
    if (userLookbook.isEmpty || index >= userLookbook.length) return;

    const imageUrl =
        'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=600';

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
    final topPad = MediaQuery.of(context).padding.top;

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
                const Positioned(
                  left: 15,
                  top: 40,
                  child: CircleAvatar(radius: 40),
                ),
                Positioned(
                  top: 20,
                  left: 130,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "${userInfo['userId'] ?? 'UID'} \n@${userInfo['nickname'] ?? 'nickname'}",
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "0 \nitems",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                          const SizedBox(width: 20),
                          Text(
                            "$lookbookCnt \nlookbook",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(width: 20),
                          const Text(
                            "0 \nAI lookbook",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(150, 35),
                        ),
                        onPressed: () => context.go('/calendarPage'),
                        child: const Text(
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

                Positioned(
                  top: topPad + 2,
                  right: 8,
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: IconButton(
                      onPressed: () {
                        // 디버그용
                        // ignore: avoid_print
                        print('MORE PRESSED');
                        _openMoreMenu();
                      },
                      icon: const Icon(
                        Icons.more_horiz,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

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
                        backgroundColor: const Color(0xFFCAD83B),
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

          const SizedBox(height: 20),

          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              itemCount: 9,
              // itemCount: userLookbook.length, 나중에 구현 다되면 하드코딩에서 이걸로 바꿀거임
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _lookbookDialog(context, index),
                  child: const Card(
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(child: Text("Click me !")),
                        ),
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
