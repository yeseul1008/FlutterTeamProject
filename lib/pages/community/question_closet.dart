import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../wardrobe/user_wardrobe_category.dart';

class QuestionCloset extends StatefulWidget {
  const QuestionCloset({super.key});

  @override
  State<QuestionCloset> createState() => _QuestionClosetState();
}

class _QuestionClosetState extends State<QuestionCloset> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  /// 현재 로그인 유저
  final String? viewerUserId = FirebaseAuth.instance.currentUser?.uid;

  /// 게시글 정보 (extra로 전달받음)
  late String closetOwnerId; // 게시글 작성자
  late String postId;        // 게시글 ID

  String? selectedCategoryId;
  bool showLikedOnly = false;

  /// 선택 상태
  final Set<String> selectedClothesIds = {};
  final Map<String, String> selectedImageUrls = {};

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;

    final extra =
    GoRouterState.of(context).extra as Map<String, dynamic>?;

    if (extra != null) {
      closetOwnerId = extra['userId'];
      postId = extra['postId'];
      _initialized = true;
    }
  }

  /// 카테고리 선택 모달
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

  /// 🔥 게시글 주인의 옷장 스트림
  Stream<QuerySnapshot<Map<String, dynamic>>> _wardrobeStream() {
    Query<Map<String, dynamic>> ref =
    fs.collection('users')
        .doc(closetOwnerId)
        .collection('wardrobe');

    if (selectedCategoryId != null && selectedCategoryId != 'all') {
      ref = ref.where('categoryId', isEqualTo: selectedCategoryId);
    }

    if (showLikedOnly) {
      ref = ref.where('liked', isEqualTo: true);
    }

    return ref.snapshots();
  }

  /// 옷 선택 토글
  void _toggleSelect(String id, String imageUrl) {
    setState(() {
      if (selectedClothesIds.contains(id)) {
        selectedClothesIds.remove(id);
        selectedImageUrls.remove(id);
      } else {
        selectedClothesIds.add(id);
        selectedImageUrls[id] = imageUrl;
      }
    });
  }

  /// 조합하기 버튼
  void _goToLookbookCombine() {
    if (selectedClothesIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('옷을 먼저 선택해주세요')),
      );
      return;
    }

    context.push(
      '/questionClosetResult',
      extra: {
        'clothesIds': selectedClothesIds.toList(),
        'imageUrls': selectedImageUrls,
        'postId': postId, // 게시글 ID
      },
    );
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

                  /// 상단 헤더
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            viewerUserId == closetOwnerId
                                ? '나의 옷장'
                                : '질문 작성자의 옷장',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),

                  const SizedBox(height: 12),

                  /// 검색 / 필터
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
                          showLikedOnly
                              ? Icons.favorite
                              : Icons.favorite_border,
                        ),
                        onPressed: () {
                          setState(() => showLikedOnly = !showLikedOnly);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  /// 옷장 그리드
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _wardrobeStream(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (!snapshot.hasData ||
                            snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text('옷장이 비어있습니다.'),
                          );
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
                            final doc = docs[index];
                            final data = doc.data();
                            final id = doc.id;
                            final imageUrl =
                            (data['imageUrl'] ?? '') as String;

                            final bool isSelected =
                            selectedClothesIds.contains(id);

                            return GestureDetector(
                              onTap: () => _toggleSelect(id, imageUrl),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF7B5CFF)
                                        : Colors.grey,
                                    width: isSelected ? 2 : 1,
                                  ),
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

                                    /// 좋아요 (본인 옷장일 때만 노출)
                                    if (viewerUserId == closetOwnerId)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints:
                                          const BoxConstraints(),
                                          icon: Icon(
                                            data['liked'] == true
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            size: 18,
                                          ),
                                          onPressed: () async {
                                            await fs
                                                .collection('users')
                                                .doc(closetOwnerId)
                                                .collection('wardrobe')
                                                .doc(id)
                                                .update({
                                              'liked':
                                              !(data['liked'] == true),
                                            });
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

            /// 조합하기 버튼
            Positioned(
              right: 16,
              bottom: 30,
              child: Material(
                color: const Color(0xFFCAD83B),
                elevation: 6,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: _goToLookbookCombine,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.black),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 16),
                        SizedBox(width: 6),
                        Text(
                          '조합하기',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ],
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
