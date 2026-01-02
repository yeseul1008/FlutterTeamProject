import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class UserScrapView extends StatelessWidget {
  final String lookbookId;

  const UserScrapView({
    super.key,
    required this.lookbookId,
  });

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        /// ✅ 뒤로가기 버튼 명시적 추가
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () {
            context.pop(); // ✅ 정상
          },
        ),

        title: const Text(
          '상세보기',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: FutureBuilder<DocumentSnapshot>(
        future: fs.collection('lookbooks').doc(lookbookId).get(),
        builder: (context, lookbookSnapshot) {
          if (lookbookSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.black),
            );
          }

          if (!lookbookSnapshot.hasData || !lookbookSnapshot.data!.exists) {
            return const Center(
              child: Text(
                '룩북을 불러올 수 없습니다',
                style: TextStyle(color: Colors.black),
              ),
            );
          }

          final lookbook =
          lookbookSnapshot.data!.data() as Map<String, dynamic>;

          final String userId = lookbook['userId'];
          final String lookbookImage = lookbook['resultImageUrl'] ?? '';
          final List<String> clothesIds =
          List<String>.from(lookbook['clothesIds'] ?? []);

          return Column(
            children: [
              /// 상단: 닉네임 + 룩북 이미지
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// 닉네임
                    FutureBuilder<DocumentSnapshot>(
                      future: fs.collection('users').doc(userId).get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData ||
                            !userSnapshot.data!.exists) {
                          return const SizedBox.shrink();
                        }

                        final user = userSnapshot.data!.data()
                        as Map<String, dynamic>;
                        final nickname = user['nickname'] ?? '';

                        if (nickname.isEmpty) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '$nickname님의 코디',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        );
                      },
                    ),

                    /// 룩북 전체 이미지
                    AspectRatio(
                      aspectRatio: 1,
                      child: lookbookImage.isEmpty
                          ? const Center(
                        child: Text(
                          '룩북 이미지 없음',
                          style: TextStyle(color: Colors.black),
                        ),
                      )
                          : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Image.network(
                            lookbookImage,
                            width: double.infinity,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              /// 하단: 옷 슬라이더
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: fs
                      .collection('users')
                      .doc(userId)
                      .collection('wardrobe')
                      .where(
                    FieldPath.documentId,
                    whereIn: clothesIds,
                  )
                      .snapshots(),
                  builder: (context, wardrobeSnapshot) {
                    if (!wardrobeSnapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.black),
                      );
                    }

                    final clothesDocs = wardrobeSnapshot.data!.docs;

                    if (clothesDocs.isEmpty) {
                      return const Center(
                        child: Text(
                          '옷 정보가 없습니다',
                          style: TextStyle(color: Colors.black),
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 130),
                      child: PageView.builder(
                        controller:
                        PageController(viewportFraction: 0.85),
                        itemCount: clothesDocs.length,
                        itemBuilder: (context, index) {
                          final cloth = clothesDocs[index].data()
                          as Map<String, dynamic>;

                          final imageUrl = cloth['imageUrl'];
                          final productName = cloth['productName'] ?? '';
                          final brand = cloth['brand'] ?? '';
                          final material = cloth['material'] ?? '';
                          final shop = cloth['shop'] ?? '';
                          final List<String> seasons =
                          List<String>.from(cloth['season'] ?? []);

                          return Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                    Colors.black.withOpacity(0.05),
                                    blurRadius: 6,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  /// 옷 이미지
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius:
                                      const BorderRadius.vertical(
                                        top: Radius.circular(16),
                                      ),
                                      child: imageUrl == null ||
                                          imageUrl.isEmpty
                                          ? const Center(
                                        child: Icon(
                                          Icons
                                              .image_not_supported,
                                          color: Colors.grey,
                                          size: 50,
                                        ),
                                      )
                                          : Image.network(
                                        imageUrl,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),

                                  /// 옷 정보
                                  Padding(
                                    padding:
                                    const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          productName,
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 16,
                                            fontWeight:
                                            FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),

                                        if (brand.isNotEmpty)
                                          Text(
                                            '브랜드: $brand',
                                            style: TextStyle(
                                              color:
                                              Colors.grey[700],
                                            ),
                                          ),

                                        if (shop.isNotEmpty)
                                          Text(
                                            '구매처: $shop',
                                            style: TextStyle(
                                              color:
                                              Colors.grey[700],
                                            ),
                                          ),

                                        if (material.isNotEmpty)
                                          Text(
                                            '재질: $material',
                                            style: TextStyle(
                                              color:
                                              Colors.grey[700],
                                            ),
                                          ),

                                        if (seasons.isNotEmpty)
                                          Text(
                                            '계절: ${seasons.join(' · ')}',
                                            style: TextStyle(
                                              color:
                                              Colors.grey[700],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
