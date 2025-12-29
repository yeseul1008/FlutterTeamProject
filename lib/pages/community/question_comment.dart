import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuestionComment extends StatefulWidget {
  const QuestionComment({super.key});

  @override
  State<QuestionComment> createState() => _QuestionCommentState();
}

class _QuestionCommentState extends State<QuestionComment> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> comments = [];
  bool isLoading = true;

  late String postId;

  /// 실제 구조 기준 댓글 불러오기
  Future<void> _getComments() async {
    try {
      final snapshot = await fs
          .collection('qna_posts')
          .doc(postId)
          .collection('qna_comments')
          .orderBy('createdAt', descending: false)
          .get();

      setState(() {
        comments = snapshot.docs;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('댓글 로딩 에러: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final extra =
    GoRouterState.of(context).extra as Map<String, dynamic>;
    postId = extra['postId'];

    _getComments();
  }

  @override
  Widget build(BuildContext context) {
    final String currentPath =
        GoRouterState.of(context).uri.path;

    return SafeArea(
      child: Column(
        children: [
          /// ===== 상단 탭 UI (기존 유지) =====
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _topButton(
                  text: 'Feed',
                  active: currentPath == '/communityMainFeed',
                  onTap: () =>
                      context.go('/communityMainFeed'),
                ),
                const SizedBox(width: 8),
                _topButton(
                  text: 'QnA',
                  active: currentPath == '/questionFeed',
                  onTap: () =>
                      context.go('/questionFeed'),
                ),
                const SizedBox(width: 8),
                _topButton(
                  text: 'Follow',
                  active: currentPath == '/followList',
                  onTap: () =>
                      context.go('/followList'),
                ),
              ],
            ),
          ),

          /// ===== 댓글 리스트 =====
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : comments.isEmpty
                ? const Center(child: Text('댓글이 없습니다'))
                : ListView.builder(
              padding:
              const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: comments.length,
              itemBuilder: (context, index) {
                final data = comments[index].data();

                return _commentItem(
                  nickname: data['authorId'] ?? '',
                  content: data['comment'] ?? '',
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// ===== 공통 탭 버튼 =====
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
            backgroundColor:
            active ? const Color(0xFFCAD83B) : Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: const BorderSide(color: Colors.black),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }

  /// ===== 댓글 카드 UI =====
  Widget _commentItem({
    required String nickname,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nickname,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(content),
        ],
      ),
    );
  }
}
