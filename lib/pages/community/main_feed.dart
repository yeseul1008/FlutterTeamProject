import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 클래스명 Dart 규칙 OK
class communityFeed extends StatelessWidget {
  const communityFeed({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentPath = GoRouterState.of(context).uri.path; // 🔧 [추가]

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            /// 상단 탭 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _tabButton(
                    text: 'feed',
                    isActive: currentPath == '/community', // 🔧 [수정]
                    onTap: () => context.go('/community'), // 🔧 [수정]
                  ),
                  _tabButton(
                    text: 'QnA',
                    isActive: currentPath == '/question', // 🔧 [수정]
                    onTap: () => context.go('/question'),
                  ),
                  _tabButton(
                    text: 'follow',
                    isActive: currentPath == '/follow', // 🔧 [수정]
                    onTap: () => context.go('/follow'),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            /// Firestore Feed List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('피드가 없습니다'));
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data =
                      docs[index].data() as Map<String, dynamic>;

                      return _FeedItem(
                        nickname: data['nickname'] ?? 'nickname',
                        userId: data['userId'] ?? '@id',
                        imageUrl: data['imageUrl'],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 탭 버튼 위젯
  Widget _tabButton({
    required String text,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 96,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFCAD83B) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.black),
        ),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// ===============================
/// 피드 아이템 UI
/// ===============================
class _FeedItem extends StatelessWidget {
  final String nickname;
  final String userId;
  final String? imageUrl;

  const _FeedItem({
    required this.nickname,
    required this.userId,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 유저 정보
          Row(
            children: [
              const CircleAvatar(radius: 18),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nickname,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(userId, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          /// 이미지
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl!,
                width: double.infinity,
                height: 240,
                fit: BoxFit.cover,
              ),
            ),

          const SizedBox(height: 12),

          /// 하단 액션
          const Row(
            children: [
              Icon(Icons.favorite_border),
              SizedBox(width: 16),
              Icon(Icons.share),
            ],
          ),
        ],
      ),
    );
  }
}
