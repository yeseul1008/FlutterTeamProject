import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserScrap extends StatefulWidget {
  const UserScrap({super.key});

  @override
  State<UserScrap> createState() => _UserScrapState();
}

class _UserScrapState extends State<UserScrap> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  late String userId;
  List<Map<String, dynamic>> scraps = [];
  bool isLoading = true;

  // 검색
  TextEditingController searchController = TextEditingController();
  String searchText = '';

  @override
  void initState() {
    super.initState();
    _loadScraps();
  }

  /// 스크랩 데이터 로드
  Future<void> _loadScraps() async {
    setState(() => isLoading = true);

    try {
      final user = auth.currentUser;
      if (user == null) return;
      userId = user.uid;

      // users/{userId}/scraps 에서 데이터 가져오기
      final scrapsSnapshot = await fs
          .collection('users')
          .doc(userId)
          .collection('scraps')
          .orderBy('scrapedAt', descending: true)
          .get();

      scraps = await Future.wait(scrapsSnapshot.docs.map((scrapDoc) async {
        final feedId = scrapDoc.data()['feedId'] ?? '';

        // feedId로 lookbooks 정보 가져오기
        String imageUrl = '';
        if (feedId.isNotEmpty) {
          final lookbookDoc =
          await fs.collection('lookbooks').doc(feedId).get();
          if (lookbookDoc.exists) {
            imageUrl = lookbookDoc.data()?['resultImageUrl'] ?? '';
          }
        }

        return {
          'feedId': feedId,
          'imageUrl': imageUrl,
          'scrapedAt': scrapDoc.data()['scrapedAt'],
        };
      }).toList());

      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('데이터를 불러오는 중 오류가 발생했습니다')),
        );
      }
    }
  }

  /// 스크랩 해제 (좋아요 해제)
  Future<void> _removeScrap(String feedId) async {
    try {
      // users/{userId}/scraps에서 삭제
      await fs
          .collection('users')
          .doc(userId)
          .collection('scraps')
          .doc(feedId)
          .delete();

      // lookbooks/{feedId}/likes에서도 삭제
      await fs
          .collection('lookbooks')
          .doc(feedId)
          .collection('likes')
          .doc(userId)
          .delete();

      // UI 업데이트
      setState(() {
        scraps.removeWhere((item) => item['feedId'] == feedId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('스크랩이 해제되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('스크랩 해제 중 오류가 발생했습니다')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 검색 필터링
    final filteredScraps = searchText.isEmpty
        ? scraps
        : scraps.where((item) {
      return item['feedId']
          .toString()
          .toLowerCase()
          .contains(searchText.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
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
                          'closet',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20),
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
                              fontWeight: FontWeight.bold, fontSize: 18),
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
                          'scrap',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 검색 바
              Row(
                children: [
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
                  const Icon(Icons.search, size: 28),
                ],
              ),

              const SizedBox(height: 16),

              // 스크랩 그리드
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredScraps.isEmpty
                    ? const Center(child: Text('스크랩한 항목이 없습니다'))
                    : GridView.builder(
                  itemCount: filteredScraps.length,
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final item = filteredScraps[index];
                    return Stack(
                      children: [
                        // 이미지
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            color: Colors.white,
                          ),
                          child: item['imageUrl'].isNotEmpty
                              ? Image.network(
                            item['imageUrl'],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) =>
                            const Center(
                              child: Icon(Icons.broken_image),
                            ),
                          )
                              : const Center(
                            child: Icon(Icons.image_not_supported),
                          ),
                        ),
                        // 좋아요 아이콘 (빨간 하트)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () => _removeScrap(item['feedId']),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.8),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite,
                                size: 18,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                      ],
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