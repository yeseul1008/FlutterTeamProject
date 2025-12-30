import 'package:flutter/material.dart';
import '../../widgets/common/main_btn.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../wardrobe/user_wardrobe_category.dart';

class UserWardrobeList extends StatefulWidget {
  const UserWardrobeList({super.key});

  @override
  State<UserWardrobeList> createState() => _UserWardrobeListState();
}

class _UserWardrobeListState extends State<UserWardrobeList> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final userId = FirebaseAuth.instance.currentUser?.uid;

  // 검색
  TextEditingController searchController = TextEditingController();
  String searchText = '';

  // 선택된 카테고리 ID
  String? selectedCategoryId;

  Map<String, dynamic> userInfo = {};

  // 좋아요 필터 토글
  bool showLikedOnly = false;

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

  void _openCategoryModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return UserWardrobeCategory(
          onSelect: (categoryId) {
            print('선택된 카테고리 ID: $categoryId');
            setState(() {
              selectedCategoryId = categoryId; // 상태에 저장
            });
            Navigator.pop(context); // 모달 닫기
          },
        );
      },
    );
  }

  // wardrobe 컬렉션 스트림
  Stream<QuerySnapshot<Map<String, dynamic>>> _wardrobeStream() {
    final ref = fs.collection('users').doc(userId).collection('wardrobe').orderBy('createdAt', descending: true);

    if (showLikedOnly) {
      return ref.where('liked', isEqualTo: true).snapshots();
    }

    return ref.snapshots();
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
            onPressed: () => context.push('/aiOutfitMaker'),
            backgroundColor: const Color(0xFFA88AEE),
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: Colors.black),
            ),
            icon: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 10),
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
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
                          setState(() {
                            searchText = value.trim();
                          });
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
                      setState(() {
                        showLikedOnly = !showLikedOnly;
                      });
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

                    // 전체 옷장 문서
                    final allDocs = snapshot.data?.docs ?? [];

                    if (allDocs.isEmpty) {
                      return const Center(child: Text('옷장이 비어있습니다.'));
                    }

                    // 검색 필터 적용
                    final filteredDocs = allDocs.where((doc) {
                      final data = doc.data();
                      final productName = (data['productName'] ?? '').toString().toLowerCase();

                      if (searchText.isEmpty) return true;

                      return productName.contains(searchText.toLowerCase());
                    }).toList();

                    // 검색 결과 없을 경우
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
                        final imageUrl = data['imageUrl'] ?? '';
                        final docId = filteredDocs[index].id;

                        return GestureDetector(
                          onTap: () => context.push(
                            '/userWardrobeDetail',
                            extra: docId,
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
            ],
          ),
        ),
      ),
    );
  }
}
