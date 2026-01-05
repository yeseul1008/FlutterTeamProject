import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../wardrobe/user_wardrobe_category.dart';

class UserWardrobeList extends StatefulWidget {
  const UserWardrobeList({super.key});

  @override
  State<UserWardrobeList> createState() => _UserWardrobeListState();
}

class _UserWardrobeListState extends State<UserWardrobeList> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final String? userId = FirebaseAuth.instance.currentUser?.uid;

  // 검색
  final TextEditingController searchController = TextEditingController();
  String searchText = '';

  // 선택된 카테고리 ID
  String? selectedCategoryId;

  Map<String, dynamic> userInfo = {};

  // 좋아요 필터 토글
  bool showLikedOnly = false;

  Future<void> _getUserInfo() async {
    if (userId == null) return;
    final snapshot = await fs.collection('users').doc(userId).get();
    if (snapshot.exists) {
      setState(() => userInfo = snapshot.data()!);
    }
  }

  void _openCategoryModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return GestureDetector(
          onTap: () => Navigator.pop(dialogContext),
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {},
              child: Center(
                child: UserWardrobeCategory(
                  onSelect: (categoryId) {
                    setState(() => selectedCategoryId = categoryId);
                    Navigator.pop(dialogContext);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _wardrobeStream() {
    if (userId == null) return const Stream.empty();

    Query<Map<String, dynamic>> ref = fs
        .collection('users')
        .doc(userId)
        .collection('wardrobe')
        .orderBy('createdAt', descending: true);

    if (selectedCategoryId != null && selectedCategoryId != 'all') {
      ref = ref.where('categoryId', isEqualTo: selectedCategoryId);
    }
    if (showLikedOnly) {
      ref = ref.where('liked', isEqualTo: true);
    }

    return ref.snapshots();
  }

  @override
  void initState() {
    super.initState();
    _getUserInfo();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const int currentIndex = 0;

    return Scaffold(
      backgroundColor: Colors.white,

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 110),
        child: SizedBox(
          height: 44,
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/aiOutfitMaker'),
            backgroundColor: const Color(0xFFA88AEE),
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: Colors.black),
            ),
            icon: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
            label: const Text(
              'AI착용샷',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 10),

              _OfficeTopTabsLime(
                currentIndex: currentIndex,
                routes: const ['/userWardrobeList', '/userLookbook', '/userScrap'],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  GestureDetector(
                    onTap: () => _openCategoryModal(context),
                    child: const Icon(Icons.menu),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: searchController,
                        onChanged: (value) => setState(() => searchText = value.trim()),
                        decoration: const InputDecoration(
                          hintText: 'search...',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(
                      showLikedOnly ? Icons.favorite : Icons.favorite_border,
                      color: Colors.black,
                    ),
                    onPressed: () => setState(() => showLikedOnly = !showLikedOnly),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _wardrobeStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allDocs = snapshot.data?.docs ?? [];
                    if (allDocs.isEmpty) {
                      return const Center(child: Text('옷장이 비어있습니다.'));
                    }

                    final filteredDocs = allDocs.where((doc) {
                      final data = doc.data();
                      final productName =
                      (data['productName'] ?? '').toString().toLowerCase();
                      if (searchText.isEmpty) return true;
                      return productName.contains(searchText.toLowerCase());
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return const Center(child: Text('검색 결과가 없습니다.'));
                    }

                    return GridView.builder(
                      itemCount: filteredDocs.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (context, index) {
                        final data = filteredDocs[index].data();
                        final String imageUrl = (data['imageUrl'] ?? '').toString();
                        final String docId = filteredDocs[index].id;

                        return GestureDetector(
                          onTap: () => context.push('/userWardrobeDetail', extra: docId),
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  color: Colors.white,
                                ),
                                child: ClipRRect(
                                  child: imageUrl.isNotEmpty
                                      ? Transform.scale(
                                    scale: 1.3,
                                    child: Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  )
                                      : null,
                                ),
                              ),
                              Positioned(
                                top: 1,
                                right: 1,
                                child: IconButton(
                                  onPressed: () async {
                                    if (userId == null) return;
                                    final docRef = fs
                                        .collection('users')
                                        .doc(userId)
                                        .collection('wardrobe')
                                        .doc(docId);

                                    final bool currentLiked = data['liked'] == true;
                                    await docRef.update({'liked': !currentLiked});
                                  },
                                  icon: data['liked'] == true
                                      ? const Icon(
                                    Icons.favorite,
                                    color: Color(0xFFE74C3C),
                                    size: 22,
                                  )
                                      : Stack(
                                    alignment: Alignment.center,
                                    children: const [
                                      Icon(Icons.favorite, color: Colors.white, size: 22),
                                      Icon(Icons.favorite_border, color: Colors.black, size: 22),
                                    ],
                                  ),
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
            ],
          ),
        ),
      ),
    );
  }
}

/// ✅ 상단탭: 연두 배경 유지 + (선택 시) 바닥에 붙는 검정 인디케이터
class _OfficeTopTabsLime extends StatelessWidget {
  const _OfficeTopTabsLime({
    required this.currentIndex,
    required this.routes,
  });

  final int currentIndex;
  final List<String> routes;

  void _go(BuildContext context, int index) {
    if (index == currentIndex) return;
    context.go(routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    const double h = 44;
    const Color lime = Color(0xFFCAD83B);

    return Container(
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black, width: 1.1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: _OfficeTabChip(
              label: 'CLOSET',
              selected: currentIndex == 0,
              selectedBg: lime,
              onTap: () => _go(context, 0),
            ),
          ),
          Container(width: 1, color: Colors.black.withOpacity(0.18)),
          Expanded(
            child: _OfficeTabChip(
              label: 'LOOKBOOKS',
              selected: currentIndex == 1,
              selectedBg: lime,
              onTap: () => _go(context, 1),
            ),
          ),
          Container(width: 1, color: Colors.black.withOpacity(0.18)),
          Expanded(
            child: _OfficeTabChip(
              label: 'SCRAP',
              selected: currentIndex == 2,
              selectedBg: lime,
              onTap: () => _go(context, 2),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficeTabChip extends StatelessWidget {
  const _OfficeTabChip({
    required this.label,
    required this.selected,
    required this.selectedBg,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: 12,
      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
      letterSpacing: 0.9,
      color: Colors.black.withOpacity(selected ? 1.0 : 0.55),
    );

    return Material(
      color: selected ? selectedBg : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.black.withOpacity(0.04),
        highlightColor: Colors.black.withOpacity(0.02),
        child: Stack(
          children: [
            Center(child: Text(label, style: textStyle)),

            // ✅ 스샷처럼: "탭의 최하단(바닥 0)에 붙고", "왼쪽에서 시작하는" 짧은 두꺼운 바
            Positioned(
              left: 35,
              bottom: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected ? 64 : 0, // 짧은 바
                height: 3,               // 두꺼운 바
                decoration: BoxDecoration(
                  color: selected ? Colors.black : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
