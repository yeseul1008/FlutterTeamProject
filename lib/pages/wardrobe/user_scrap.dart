import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserScrap extends StatefulWidget {
  const UserScrap({super.key});

  @override
  State<UserScrap> createState() => _UserScrapState();
}

class _UserScrapState extends State<UserScrap> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  // late String userId;
  List<Map<String, dynamic>> scraps = [];
  bool isLoading = true;

  final userId = FirebaseAuth.instance.currentUser?.uid;

  // 검색
  TextEditingController searchController = TextEditingController();
  String searchText = '';

  Future<void> deleteScrap(String feedId) async {
    if (userId == null) return;

    final snapshot = await fs
        .collection('users')
        .doc(userId)
        .collection('scraps')
        .where('feedId', isEqualTo: feedId)
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }


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
      // userId = user.uid;

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

    const int selectedIndex = 2;

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
              _SleekTopTabs(
                selectedIndex: selectedIndex,
                onTapCloset: () => context.go('/userWardrobeList'),
                onTapLookbooks: () => context.go('/userLookbook'),
                onTapScrap: () => context.go('/userScrap'),
              ),

              const SizedBox(height: 18),

              // 검색 바
              // Row(
              //   children: [
              //     const SizedBox(width: 8),
              //     Expanded(
              //       child: Container(
              //         height: 36,
              //         padding: const EdgeInsets.symmetric(horizontal: 12),
              //         decoration: BoxDecoration(
              //           border: Border.all(color: Colors.black),
              //           borderRadius: BorderRadius.circular(20),
              //         ),
              //         child: TextField(
              //           controller: searchController,
              //           onChanged: (value) {
              //             setState(() {
              //               searchText = value.trim();
              //             });
              //           },
              //           decoration: const InputDecoration(
              //             hintText: 'search...',
              //             border: InputBorder.none,
              //             isDense: true,
              //           ),
              //         ),
              //       ),
              //     ),
              //     const SizedBox(width: 12),
              //     const Icon(Icons.search, size: 28),
              //   ],
              // ),

              // const SizedBox(height: 16),

              // 스크랩 그리드
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: fs
                      .collection('users')
                      .doc(userId)
                      .collection('scraps')
                      .snapshots(),
                  builder: (context, scrapSnapshot) {
                    if (!scrapSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // feedId 리스트 추출
                    final feedIds = scrapSnapshot.data!.docs
                        .map((doc) => doc['feedId'] as String)
                        .toList();

                    if (feedIds.isEmpty) {
                      return const Center(child: Text('스크랩한 게시물이 없습니다.'));
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: fs
                          .collection('lookbooks')
                          .where(
                        FieldPath.documentId,
                        whereIn: feedIds,
                      )
                          .snapshots(),
                      builder: (context, lookbookSnapshot) {
                        if (!lookbookSnapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final lookbooks = lookbookSnapshot.data!.docs;

                        return GridView.builder(
                          itemCount: lookbooks.length,
                          gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1,
                          ),
                          itemBuilder: (context, index) {
                            final doc = lookbooks[index];
                            final data =
                            lookbooks[index].data() as Map<String, dynamic>;

                            return GestureDetector(
                              onTap: () {
                                context.push(
                                  '/userScrapView',
                                  extra: doc.id,
                                );
                              },

                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      image: DecorationImage(
                                        image: NetworkImage(data['resultImageUrl']),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () async {
                                        await deleteScrap(doc.id);
                                      },
                                      icon: const Icon(
                                        Icons.favorite,
                                        color: Color(0xFFCAD83B),
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );

                          },
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
