import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityMainFeed extends StatefulWidget {
  const CommunityMainFeed({super.key});

  @override
  State<CommunityMainFeed> createState() => _CommunityMainFeedState();
}

class _CommunityMainFeedState extends State<CommunityMainFeed> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  // 하드코딩
  String userId = 'TEST1';
  String nickname = '정전기';

  Map<String, dynamic> qnaPost = {};

  Future<void> _getQnaPost() async {
    final qnaPostSnapshot = await fs.collection('qna_posts')
        .where('authorId', isEqualTo: userId)
        .get();

    print('Number of documents found: ${qnaPostSnapshot.docs.length}');

    setState(() {
      if (qnaPostSnapshot.docs.isNotEmpty) {
        qnaPost = qnaPostSnapshot.docs.first.data();
        print(qnaPost);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _getQnaPost(); // initState에서 데이터 로드
  }

  @override
  Widget build(BuildContext context) {
    final String currentPath = GoRouterState.of(context).uri.path;

    return SafeArea(
      child: Column(
        children: [
          /// ===== 상단 UI =====
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                _topButton(
                  text: 'Feed',
                  active: currentPath == '/communityMainFeed',
                  onTap: () => context.go('/communityMainFeed'),
                ),
                SizedBox(width: 8),
                _topButton(
                  text: 'QnA',
                  active: currentPath == '/questionFeed',
                  onTap: () => context.go('/questionFeed'),
                ),
                SizedBox(width: 8),
                _topButton(
                  text: 'Follow',
                  active: currentPath == '/followList',
                  onTap: () => context.go('/followList'),
                ),
              ],
            ),
          ),

          /// ===== Feed Body ===== 하드코딩 데이터 표시
          Expanded(
            child: Stack(
              children: [
                /// ===== Feed 게시글 표시 =====
                qnaPost.isEmpty
                    ? Center(
                  child: CircularProgressIndicator(),
                )
                    : ListView(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 100),
                  children: [
                    _qnaItem(
                      nickname: nickname, // 하드코딩 닉네임
                      authorId: userId,   // 하드코딩 userId
                      imageUrl: qnaPost['imageUrl'] ?? '',
                      commentCount: qnaPost['commentCount'] ?? 0,
                    ),
                  ],
                ),

                /// ===== post a look 버튼 =====
                Positioned(
                  bottom: 25,
                  right: 30,
                  child: ElevatedButton(
                    onPressed: () {
                      context.go('/questionAdd');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFCAD83B),
                      foregroundColor: Colors.black,
                      elevation: 2,
                      padding: EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'post a look',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ===== 상단 버튼 공통 ===== 버튼 위젯 분리
  Widget _topButton({
    required String text,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: SizedBox(
        height: 50,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: active ? Color(0xFFCAD83B) : Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: BorderSide(color: Colors.black),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }

  /// ===== QnA 카드 UI ===== 카드 위젯
  Widget _qnaItem({
    required String nickname,
    required String authorId,
    required String imageUrl,
    required int commentCount,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 상단 정보 + 더보기
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                /// 프로필 이미지
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Icon(Icons.person, color: Colors.grey),
                ),
                SizedBox(width: 12),

                /// 닉네임 & ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nickname,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '@$authorId',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                /// 더보기 버튼
                IconButton(
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          /// 이미지
          Container(
            width: double.infinity,
            height: 280,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          /// 댓글 수
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Icon(Icons.favorite_border, size: 20, color: Colors.grey.shade700),
                const SizedBox(width: 6),
                Text(
                  commentCount.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}