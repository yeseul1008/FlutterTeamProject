import 'package:flutter/material.dart';
import '../../widgets/common/main_btn.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserWardrobeList extends StatefulWidget {
  const UserWardrobeList({super.key});

  @override
  State<UserWardrobeList> createState() => _UserWardrobeListState();
}

class _UserWardrobeListState extends State<UserWardrobeList> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  String userId = 'tHuRzoBNhPhONwrBeUME';
  Map<String, dynamic> userInfo = {};

  // 사용자 정보 가져오기
  Future<void> _getUserInfo() async {
    final snapshot = await fs.collection('users').doc(userId).get();
    if (snapshot.exists) {
      setState(() {
        userInfo = snapshot.data()!;
      });
      print(userInfo);
    } else {
      print('User not found');
    }
  }

  // wardrobe 컬렉션 스트림
  Stream<QuerySnapshot<Map<String, dynamic>>> _wardrobeStream() {
    return fs
        .collection('users')
        .doc(userId)
        .collection('wardrobe')
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    _getUserInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // AI 착용샷 버튼
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: SizedBox(
          height: 44,
          child: FloatingActionButton.extended(
            onPressed: () {},
            backgroundColor: const Color(0xFFA88AEE),
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: Colors.black),
            ),
            icon: const Icon(
              Icons.auto_awesome,
              size: 18,
              color: Colors.white,
            ),
            label: const Text(
              'ai착용샷',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 30),

            // 상단 버튼 3개
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => context.go('/userWardrobeList'),
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
                        'closet',
                        style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => context.go('/userLookbook'),
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
                        'lookbooks',
                        style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => context.go('/userScrap'),
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
                        'scrap',
                        style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 검색 바 영역
            Row(
              children: [
                const Icon(Icons.menu),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: const [
                        Expanded(
                          child: Text(
                            'search...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        Icon(Icons.search, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.favorite_border),
              ],
            ),

            const SizedBox(height: 16),

            // 옷 그리드
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _wardrobeStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('옷장이 비어있습니다.'));
                  }

                  final docs = snapshot.data!.docs;

                  return GridView.builder(
                    itemCount: docs.length,
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.7,
                    ),
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final imageUrl = data['imageUrl'] ?? '';
                      final docId = docs[index].id; // 문서 ID

                      return GestureDetector(
                        onTap: () => context.push(
                          '/userWardrobeDetail',
                          extra: docs[index].id, // String만 전달
                        ),
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                color: Colors.white,
                                image: imageUrl.isNotEmpty
                                    ? DecorationImage(
                                  image: NetworkImage(imageUrl),
                                  fit: BoxFit.cover,
                                )
                                    : null,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton(
                                icon: Icon(
                                  data['liked'] == true
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: Colors.black,
                                  size: 18,
                                ),
                                onPressed: () async {
                                  final docRef = fs
                                      .collection('users')
                                      .doc(userId)
                                      .collection('wardrobe')
                                      .doc(docId);

                                  final currentLiked = data['liked'] == true;
                                  await docRef.update({'liked': !currentLiked});
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // 화면 하단에 사용자 닉네임 출력
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child: Text(
                'User: ${userInfo['nickname'] ?? 'Loading...'}',
                style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
