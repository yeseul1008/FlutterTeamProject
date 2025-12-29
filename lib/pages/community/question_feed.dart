import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

class QuestionFeed extends StatefulWidget {
  const QuestionFeed({super.key});

  @override
  State<QuestionFeed> createState() => _QuestionFeedState();
}

class _QuestionFeedState extends State<QuestionFeed> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  // 하드코딩
  String userId = 'TEST1';
  String nickname = '정전기';

  Map<String, dynamic> qnaPost = {};

  Future<void> _getQnaPost() async {
    final qnaPostSnapshot = await fs
        .collection('qna_posts')
        .where('authorId', isEqualTo: userId)
        .get();

    setState(() {
      if (qnaPostSnapshot.docs.isNotEmpty) {
        qnaPost = qnaPostSnapshot.docs.first.data();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _getQnaPost();
  }

  @override
  Widget build(BuildContext context) {
    final String currentPath = GoRouterState.of(context).uri.path;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _topButton(
                  text: 'Feed',
                  active: currentPath == '/communityMainFeed',
                  onTap: () => context.go('/communityMainFeed'),
                ),
                const SizedBox(width: 8),
                _topButton(
                  text: 'QnA',
                  active: currentPath == '/questionFeed',
                  onTap: () => context.go('/questionFeed'),
                ),
                const SizedBox(width: 8),
                _topButton(
                  text: 'Follow',
                  active: currentPath == '/followList',
                  onTap: () => context.go('/followList'),
                ),
              ],
            ),
          ),

          Expanded(
            child: Stack(
              children: [
                qnaPost.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  children: [
                    _qnaItem(
                      nickname: nickname,
                      authorId: userId,
                      imageUrl: qnaPost['imageUrl'] ?? '',
                      commentCount: qnaPost['commentCount'] ?? 0,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
            backgroundColor: active ? const Color(0xFFCAD83B) : Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: const BorderSide(color: Colors.black),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  /// ===== QnA 카드 UI  =====
  Widget _qnaItem({
    required String nickname,
    required String authorId,
    required String imageUrl,
    required int commentCount,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Icon(Icons.person, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nickname,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('@$authorId',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              qnaPost['content'] ?? '질문이 없습니다',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            height: 280,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline),
                const SizedBox(width: 6),
                Text(commentCount.toString()),
                const Spacer(),

                /// [공유 활성화]
                // IconButton(
                //   icon: const Icon(Icons.share),
                //   onPressed: () {
                //     Share.share(
                //       '${qnaPost['content']}\n\n$imageUrl',
                //     );
                //   },
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
