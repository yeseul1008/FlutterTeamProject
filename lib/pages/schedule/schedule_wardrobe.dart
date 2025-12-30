import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../wardrobe/user_wardrobe_category.dart';

class ScheduleWardrobe extends StatefulWidget {
  const ScheduleWardrobe({super.key});

  @override
  State<ScheduleWardrobe> createState() => _ScheduleWardrobeState();
}

class _ScheduleWardrobeState extends State<ScheduleWardrobe> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final String? userId = FirebaseAuth.instance.currentUser?.uid;

  String? selectedCategoryId;
  bool showLikedOnly = false;

  void _openCategoryModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return UserWardrobeCategory(
          onSelect: (categoryId) {
            setState(() => selectedCategoryId = categoryId);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _wardrobeStream() {
    if (userId == null) return const Stream.empty();

    Query<Map<String, dynamic>> ref =
    fs.collection('users').doc(userId).collection('wardrobe');

    if (selectedCategoryId != null && selectedCategoryId!.isNotEmpty) {
      ref = ref.where('categoryId', isEqualTo: selectedCategoryId);
    }

    if (showLikedOnly) {
      ref = ref.where('liked', isEqualTo: true);
    }

    return ref.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // 상단: 뒤로가기 + 타이틀 pill
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.go('/scheduleAdd'),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      ),
                      Expanded(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 26, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFA88AEE),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: Colors.black),
                            ),
                            child: const Text(
                              '나의 옷장',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // 좌우 균형용
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 검색바 라인: 메뉴 + 검색 + 하트(필터)
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _openCategoryModal(context),
                        child: const Icon(Icons.menu, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
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
                      const SizedBox(width: 10),
                      IconButton(
                        icon: Icon(
                          showLikedOnly ? Icons.favorite : Icons.favorite_border,
                          color: Colors.black,
                        ),
                        onPressed: () {
                          setState(() => showLikedOnly = !showLikedOnly);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 그리드
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _wardrobeStream(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(child: Text('옷장이 비어있습니다.'));
                        }

                        final docs = snapshot.data!.docs;

                        return GridView.builder(
                          padding: const EdgeInsets.only(bottom: 120),
                          itemCount: docs.length,
                          gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.72,
                          ),
                          itemBuilder: (context, index) {
                            final data = docs[index].data();
                            final imageUrl = (data['imageUrl'] ?? '') as String;
                            final docId = docs[index].id;

                            return GestureDetector(
                              onTap: () => context.push(
                                '/userWardrobeDetail',
                                extra: docId,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Stack(
                                  children: [
                                    if (imageUrl.isNotEmpty)
                                      Positioned.fill(
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(
                                          data['liked'] == true
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: Colors.black,
                                          size: 18,
                                        ),
                                        onPressed: () async {
                                          if (userId == null) return;

                                          final docRef = fs
                                              .collection('users')
                                              .doc(userId)
                                              .collection('wardrobe')
                                              .doc(docId);

                                          final currentLiked =
                                              data['liked'] == true;
                                          await docRef
                                              .update({'liked': !currentLiked});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // 우하단 "조합하기" 버튼 (스크린샷처럼)
            Positioned(
              right: 16,
              bottom: 90, // 바텀네비(있다면) 위로 띄우기
              child: SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: 조합하기 동작 연결
                    // 예) context.push('/aiOutfitMaker');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCAD83B),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: Colors.black),
                    ),
                  ),
                  child: const Text(
                    '조합하기',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
