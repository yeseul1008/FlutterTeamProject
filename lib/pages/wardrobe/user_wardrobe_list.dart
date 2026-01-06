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
      setState(() {
        userInfo = snapshot.data()!;
      });
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
    // 현재 페이지: closet
    const int selectedIndex = 0;

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

              // ✅ 세련된 상단탭 (슬라이딩 인디케이터 + 아이콘/텍스트)
              _SleekTopTabs(
                selectedIndex: selectedIndex,
                onTapCloset: () => context.go('/userWardrobeList'),
                onTapLookbooks: () => context.go('/userLookbook'),
                onTapScrap: () => context.go('/userScrap'),
              ),

              const SizedBox(height: 12),

              // 검색 바 영역
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
                        onChanged: (value) {
                          setState(() => searchText = value.trim());
                        },
                        decoration: const InputDecoration(
                          hintText: 'search...',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ❤️ 하트 필터 버튼
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

              // 옷 그리드
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
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (context, index) {
                        final data = filteredDocs[index].data();
                        final String imageUrl =
                        (data['imageUrl'] ?? '').toString();
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

                                    final bool currentLiked =
                                        data['liked'] == true;
                                    await docRef
                                        .update({'liked': !currentLiked});
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
                                      Icon(
                                        Icons.favorite,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                      Icon(
                                        Icons.favorite_border,
                                        color: Colors.black,
                                        size: 22,
                                      ),
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

/// ===============================
/// ✅ 가장 무난하고 “세련되게” 보이는: 슬라이딩 인디케이터 탭
/// - 전체는 얇은 테두리/라운드
/// - 선택은 내부 인디케이터(살짝 떠 보이는 느낌)
/// - 아이콘+텍스트(가독성/완성도 좋음)
/// ===============================
class _SleekTopTabs extends StatelessWidget {
  const _SleekTopTabs({
    required this.selectedIndex,
    required this.onTapCloset,
    required this.onTapLookbooks,
    required this.onTapScrap,
  });

  final int selectedIndex;
  final VoidCallback onTapCloset;
  final VoidCallback onTapLookbooks;
  final VoidCallback onTapScrap;

  Alignment _indicatorAlign() {
    if (selectedIndex == 0) return Alignment.centerLeft;
    if (selectedIndex == 1) return Alignment.center;
    return Alignment.centerRight;
  }

  @override
  Widget build(BuildContext context) {
    const double height = 50;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, c) {
          final double w = c.maxWidth;
          final double segmentW = w / 3;

          return Stack(
            children: [
              // 바탕(테두리만)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 1.2),
                  borderRadius: BorderRadius.circular(26),
                ),
              ),

              // 선택 인디케이터(슬라이드)
              AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: _indicatorAlign(),
                child: Container(
                  width: segmentW,
                  height: height,
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFCAD83B), // 기존 감성 유지
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.black, width: 1.2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 탭 버튼들
              Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      selected: selectedIndex == 0,
                      icon: Icons.checkroom,
                      label: 'closet',
                      onTap: onTapCloset,
                    ),
                  ),
                  Expanded(
                    child: _TabButton(
                      selected: selectedIndex == 1,
                      icon: Icons.auto_awesome_mosaic,
                      label: 'lookbooks',
                      onTap: onTapLookbooks,
                    ),
                  ),
                  Expanded(
                    child: _TabButton(
                      selected: selectedIndex == 2,
                      icon: Icons.bookmark,
                      label: 'scrap',
                      onTap: onTapScrap,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextStyle textStyle = TextStyle(
      fontWeight: FontWeight.w900,
      fontSize: 17,
      color: Colors.black,
      letterSpacing: 0.2,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        splashColor: Colors.black.withOpacity(0.05),
        highlightColor: Colors.black.withOpacity(0.03),
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: selected ? 1.0 : 0.85,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: Colors.black),
                const SizedBox(width: 6),
                Text(label, style: textStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
