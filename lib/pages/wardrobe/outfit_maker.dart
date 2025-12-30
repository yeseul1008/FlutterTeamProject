import 'package:flutter/material.dart';
import '../../widgets/common/main_btn.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../wardrobe/user_wardrobe_category.dart';

class AiOutfitMaker extends StatefulWidget {
  const AiOutfitMaker({super.key});

  @override
  State<AiOutfitMaker> createState() => _AiOutfitMakerState();
}

class _AiOutfitMakerState extends State<AiOutfitMaker> {
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

  // 선택된 옷 문서 ID
  Set<String> selectedWardrobeIds = {};

  // 사용자 정보 가져오기
  Future<void> _getUserInfo() async {
    final snapshot = await fs.collection('users').doc(userId).get();
    if (snapshot.exists) {
      setState(() {
        userInfo = snapshot.data()!;
      });
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
            setState(() {
              selectedCategoryId = categoryId;
            });
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _wardrobeStream() {
    if (userId == null) return const Stream.empty();

    var ref = fs
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 110),
        child: Builder(
          builder: (context) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _wardrobeStream(),
              builder: (context, snapshot) {
                return SizedBox(
                  height: 55,
                  width: 220,
                  child: Material(
                    borderRadius: BorderRadius.circular(30),
                    elevation: 6,
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFA88AEE), Color(0xFFCAD83B)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.black),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        // 기존 onTap에서 context.push 호출 부분
                        onTap: () {
                          if (selectedWardrobeIds.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('하나 이상의 옷을 선택해주세요.'),
                              ),
                            );
                            return;
                          }

                          // 선택된 옷 이미지 URL 리스트 추출
                          final selectedUrls = snapshot.data!.docs
                              .where((doc) => selectedWardrobeIds.contains(doc.id))
                              .map((doc) => (doc.data()['imageUrl'] ?? '') as String)
                              .where((url) => url.isNotEmpty) // 빈 문자열 제거
                              .toList();

                          // 콘솔에 출력
                          print('선택된 옷 URL: $selectedUrls');

                          // AI 생성 화면으로 이동 (빈 리스트도 전달)
                          context.push(
                            '/aiOutfitMakerScreen',
                            extra: selectedUrls.isNotEmpty ? selectedUrls : <String>[],
                          );
                        },


                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.auto_awesome,
                              size: 20,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'ai착용샷 생성',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Wearing ai clothes',
          style: TextStyle(color: Colors.black),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 10),
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
                      final productName = (data['productName'] ?? '')
                          .toString()
                          .toLowerCase();
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
                        final imageUrl = data['imageUrl'] ?? '';
                        final docId = filteredDocs[index].id;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (selectedWardrobeIds.contains(docId)) {
                                selectedWardrobeIds.remove(docId);
                              } else {
                                selectedWardrobeIds.add(docId);
                              }
                            });
                          },
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  color: Colors.white,
                                ),
                                child: ClipRRect(
                                  // 사진 확대 적용
                                  child: imageUrl.isNotEmpty
                                      ? Transform.scale(
                                          scale: 1.3, // 확대 정도 조정 가능
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
                                top: 0,
                                right: 0,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: data['liked'] == true
                                      ? const Icon(
                                          Icons.favorite,
                                          color: Colors.black,
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
                                  onPressed: () async {
                                    final docRef = fs
                                        .collection('users')
                                        .doc(userId)
                                        .collection('wardrobe')
                                        .doc(docId);
                                    final currentLiked = data['liked'] == true;
                                    await docRef.update({
                                      'liked': !currentLiked,
                                    });
                                  },
                                ),
                              ),
                              if (selectedWardrobeIds.contains(docId))
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black26,
                                    child: const Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 32,
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
