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
  final TextEditingController _commentController = TextEditingController();

  List<QueryDocumentSnapshot<Map<String, dynamic>>> comments = [];
  bool isLoading = true;
  late String postId;
  String currentUserId = 'current_user'; // 현재 로그인된 사용자 ID, 실제 로그인 상태에서 가져와야 합니다.

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

  /// 댓글 추가
  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      await fs
          .collection('qna_posts')
          .doc(postId)
          .collection('qna_comments')
          .add({
        'comment': _commentController.text.trim(),
        'authorId': currentUserId, // 실제로는 현재 로그인한 사용자 ID
        'createdAt': FieldValue.serverTimestamp(),
        'isLiked': false, // 기본적으로 좋아요는 없으므로 false로 설정
      });

      _commentController.clear();
      _getComments(); // 댓글 목록 새로고침
    } catch (e) {
      debugPrint('댓글 추가 에러: $e');
    }
  }

  /// 댓글 삭제
  Future<void> _deleteComment(String commentId) async {
    try {
      await fs
          .collection('qna_posts')
          .doc(postId)
          .collection('qna_comments')
          .doc(commentId)
          .delete();
      _getComments(); // 댓글 목록 새로고침
    } catch (e) {
      debugPrint('댓글 삭제 실패: $e');
    }
  }

  /// 댓글 수정
  Future<void> _editComment(String commentId, String currentComment) async {
    TextEditingController _editController = TextEditingController(text: currentComment);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('댓글 수정'),
          content: TextField(
            controller: _editController,
            decoration: const InputDecoration(hintText: '수정할 댓글 입력'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_editController.text.trim().isEmpty) return;
                try {
                  await fs
                      .collection('qna_posts')
                      .doc(postId)
                      .collection('qna_comments')
                      .doc(commentId)
                      .update({
                    'comment': _editController.text.trim(),
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(context);
                  _getComments(); // 댓글 목록 새로고침
                } catch (e) {
                  debugPrint('댓글 수정 실패: $e');
                }
              },
              child: const Text('수정'),
            ),
          ],
        );
      },
    );
  }

  /// 댓글 좋아요 상태 업데이트
  Future<void> _toggleLike(String commentId, bool currentLikeStatus) async {
    try {
      await fs
          .collection('qna_posts')
          .doc(postId)
          .collection('qna_comments')
          .doc(commentId)
          .update({
        'isLiked': !currentLikeStatus, // 좋아요 상태 반전
      });

      _getComments(); // 댓글 목록 새로고침
    } catch (e) {
      debugPrint('좋아요 상태 업데이트 실패: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final extra = GoRouterState.of(context).extra as Map<String, dynamic>;
    postId = extra['postId'];

    _getComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String currentPath = GoRouterState.of(context).uri.path;

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

          /// ===== COMMENTS 헤더 =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mark_unread_chat_alt_outlined, size: 24),
                const SizedBox(width: 8),
                Text(
                  'COMMENTS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 10),
                // 해당란 표시 추가
                Container(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Color(0xFF7C4DFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'New', // 해당란 표시
                    style: TextStyle(color: Colors.white),
                  ),
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              itemCount: comments.length,
              itemBuilder: (context, index) {
                final data = comments[index].data();
                final commentId = comments[index].id;

                // 작성자 ID와 현재 로그인한 사용자 ID 비교
                bool isAuthor = data['authorId'] == currentUserId;

                return _commentItem(
                  nickname: data['authorId'] ?? '',
                  content: data['comment'] ?? '',
                  commentId: commentId,
                  isLiked: data['isLiked'] ?? false, // 좋아요 상태
                  isAuthor: isAuthor, // 작성자만 수정 및 삭제 가능
                );
              },
            ),
          ),

          /// ===== 댓글 입력 영역 =====
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'add a comment ...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide(color: Colors.grey[400]!),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _addComment,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Color(0xFF7C4DFF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_upward,
                      color: Colors.white,
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
    required String commentId,
    required bool isLiked, // 좋아요 상태
    required bool isAuthor, // 작성자 여부 추가
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white, // 배경 흰색으로 설정
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 프로필 이미지
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
          ),
          const SizedBox(width: 12),

          // 댓글 내용
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '@id',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),

          // 수정, 삭제 버튼 추가 (작성자만)
          if (isAuthor)
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    _editComment(commentId, content);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    _deleteComment(commentId);
                  },
                ),
              ],
            ),

          // 좋아요 버튼 (빈 하트 -> 빨간색 하트로 변경)
          IconButton(
            onPressed: () {
              _toggleLike(commentId, isLiked);
            },
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border, // 하트 채우기/빈 하트
              color: isLiked ? Colors.red : Colors.black,
            ),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
