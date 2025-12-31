import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../wardrobe/user_wardrobe_category.dart';

/// =============================
/// ScheduleWardrobe.dart
/// ✅ 역할: 옷 선택만 하고 -> 선택값을 UserScheduleAdd로 pop 전달
/// ❌ 여기서 /scheduleCombine 절대 push 하지 않음 (중복 Combine 방지)
/// =============================
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

  // ✅ 선택 상태
  final Set<String> selectedClothesIds = {};
  final Map<String, String> selectedImageUrls = {};

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

  // ✅ 조합하기 버튼: "선택값만" 상위(UserScheduleAdd)로 넘기고 pop
  Future<void> _returnSelectionToAdd() async {
    if (selectedClothesIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('옷을 먼저 선택해주세요')),
      );
      return;
    }

    context.pop({
      'clothesIds': selectedClothesIds.toList(),
      'imageUrls': selectedImageUrls,
    });
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

                  // 🔹 상단
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            '나의 옷장',
                            style: TextStyle(
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

                  // 🔹 검색 / 필터
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

                  // 🔹 그리드
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
                            final doc = docs[index];
                            final data = doc.data();
                            final id = doc.id;
                            final imageUrl = (data['imageUrl'] ?? '') as String;

                            final bool isSelected =
                            selectedClothesIds.contains(id);

                            return GestureDetector(
                              onTap: () => _toggleSelect(id, imageUrl),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
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

                                          await fs
                                              .collection('users')
                                              .doc(userId)
                                              .collection('wardrobe')
                                              .doc(id)
                                              .update({
                                            'liked': !(data['liked'] == true),
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

            // 🔹 조합하기 버튼: ✅ 선택값만 pop
            Positioned(
              right: 16,
              bottom: 90,
              child: Material(
                color: const Color(0xFFCAD83B),
                elevation: 6,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: _returnSelectionToAdd,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
