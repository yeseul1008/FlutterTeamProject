import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class QuestionComment extends StatefulWidget {
  const QuestionComment({super.key});

  @override
  State<QuestionComment> createState() => _QuestionCommentState();
}

class _QuestionCommentState extends State<QuestionComment> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final TextEditingController _commentController = TextEditingController();

  List<Map<String, dynamic>> comments = [];
  bool isLoading = true;
  late String postId;
  late String postAuthorId; // 게시글 주인의 아이디
  String currentUserId = '';
  int commentCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    if (extra != null) {
      postId = extra['postId'];
      _loadPostAuthor(); // 게시글 작성자 조회
      _getComments();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// 게시글 작성자 조회
  Future<void> _loadPostAuthor() async {
    try {
      final doc = await fs.collection('questions').doc(postId).get();
      postAuthorId = doc.data()?['authorId'] ?? '';
    } catch (e) {
      debugPrint('게시글 작성자 조회 실패: $e');
    }
  }

  /// 댓글 불러오기
  Future<void> _getComments() async {
    try {
      final user = auth.currentUser;
      if (user != null) currentUserId = user.uid;

      final snapshot = await fs
          .collection('questions')
          .doc(postId)
          .collection('qna_comments')
          .orderBy('createdAt', descending: false)
          .get();

      comments = await Future.wait(snapshot.docs.map((doc) async {
        final data = doc.data();
        final String authorId = data['authorId'] ?? '';

        String authorNickname = 'Unknown';
        String profileImageUrl = '';
        String loginId = 'Unknown';

        if (authorId.isNotEmpty) {
          final userDoc = await fs.collection('users').doc(authorId).get();
          authorNickname = userDoc.data()?['nickname'] ?? 'Unknown';
          profileImageUrl = userDoc.data()?['profileImageUrl'] ?? '';
          loginId = userDoc.data()?['loginId'] ?? 'Unknown';
        }

        final likesSnapshot = await fs
            .collection('questions')
            .doc(postId)
            .collection('qna_comments')
            .doc(doc.id)
            .collection('likes')
            .get();

        final bool isLiked =
        likesSnapshot.docs.any((likeDoc) => likeDoc.id == currentUserId);

        return {
          'commentId': doc.id,
          'authorId': authorId,
          'loginId': loginId,
          'authorNickname': authorNickname,
          'authorProfileImageUrl': profileImageUrl,
          'comment': data['comment'] ?? '',
          'commentImgUrl': data['commentImg'] ?? '', // 이미지 URL 포함
          'likeCount': likesSnapshot.size,
          'isLiked': isLiked,
          'createdAt': data['createdAt'],
        };
      }).toList());

      setState(() {
        commentCount = comments.length;
        isLoading = false;
      });

      await fs.collection('questions').doc(postId).update({
        'commentCount': commentCount,
      });
    } catch (e) {
      debugPrint('댓글 로딩 에러: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  /// 댓글 추가
  Future<void> _addComment({String? commentImgUrl}) async {
    if (_commentController.text.trim().isEmpty) return;

    final user = auth.currentUser;
    if (user == null) return;

    try {
      await fs
          .collection('questions')
          .doc(postId)
          .collection('qna_comments')
          .add({
        'comment': _commentController.text.trim(),
        'authorId': user.uid,
        'commentImg': commentImgUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _commentController.clear();
      _getComments();
    } catch (e) {
      debugPrint('댓글 추가 에러: $e');
    }
  }

  /// 댓글 삭제
  Future<void> _deleteComment(String commentId) async {
    try {
      await fs
          .collection('questions')
          .doc(postId)
          .collection('qna_comments')
          .doc(commentId)
          .delete();
      _getComments();
    } catch (e) {
      debugPrint('댓글 삭제 실패: $e');
    }
  }

  /// 댓글 수정
  Future<void> _editComment(String commentId, String currentComment) async {
    final editController = TextEditingController(text: currentComment);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('댓글 수정'),
          content: TextField(
            controller: editController,
            decoration: const InputDecoration(hintText: '수정할 댓글 입력'),
            maxLines: 3,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (editController.text.trim().isEmpty) return;
                Navigator.pop(dialogContext);
                try {
                  await fs
                      .collection('questions')
                      .doc(postId)
                      .collection('qna_comments')
                      .doc(commentId)
                      .update({
                    'comment': editController.text.trim(),
                  });
                  _getComments();
                } catch (e) {
                  debugPrint('댓글 수정 실패: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('댓글 수정 중 오류가 발생했습니다')),
                  );
                }
              },
              child: const Text('수정'),
            ),
          ],
        );
      },
    );
  }

  /// 댓글 좋아요 토글
  Future<void> _toggleLike(String commentId, bool isLiked) async {
    final likeRef = fs
        .collection('questions')
        .doc(postId)
        .collection('qna_comments')
        .doc(commentId)
        .collection('likes')
        .doc(currentUserId);

    setState(() {
      final comment = comments.firstWhere((c) => c['commentId'] == commentId);
      if (isLiked) {
        comment['isLiked'] = false;
        comment['likeCount']--;
      } else {
        comment['isLiked'] = true;
        comment['likeCount']++;
      }
    });

    try {
      if (isLiked) {
        await likeRef.delete();
      } else {
        await likeRef.set({'likedAt': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      setState(() {
        final comment = comments.firstWhere((c) => c['commentId'] == commentId);
        if (isLiked) {
          comment['isLiked'] = true;
          comment['likeCount']++;
        } else {
          comment['isLiked'] = false;
          comment['likeCount']--;
        }
      });
      debugPrint('좋아요 토글 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentPath = GoRouterState.of(context).uri.path;

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            /// 상단 탭 UI
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

            /// COMMENTS 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go('/questionFeed'),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.mark_unread_chat_alt_outlined, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'COMMENTS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCAD83B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$commentCount',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            /// 댓글 리스트
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : comments.isEmpty
                  ? const Center(child: Text('댓글이 없습니다'))
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  bool isAuthor = comment['authorId'] == currentUserId;

                  return _commentItem(
                    nickname: comment['authorNickname'],
                    authorId: comment['authorId'],
                    loginId: comment['loginId'],
                    profileImageUrl: comment['authorProfileImageUrl'],
                    content: comment['comment'],
                    commentId: comment['commentId'],
                    likeCount: comment['likeCount'],
                    isLiked: comment['isLiked'],
                    isAuthor: isAuthor,
                    commentImgUrl: comment['commentImgUrl'],
                  );
                },
              ),
            ),

            /// 댓글 입력 영역
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
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
                        filled: true,
                        fillColor: Colors.white,
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  /// 📷 이미지 버튼 (추가)
                  GestureDetector(
                    onTap: () {
                      if (postAuthorId.isEmpty) return;

                      context.push(
                        '/questionCloset',
                        extra: {
                          'userId': postAuthorId, // 게시글 주인 ID
                          'postId': postId,       // 게시글 ID
                        },
                      );
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.checkroom,
                        color: Colors.black,
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _addComment(), // 여기서 바로 댓글 업로드
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFFCAD83B),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 공통 탭 버튼
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }

  /// 댓글 카드 UI
  Widget _commentItem({
    required String nickname,
    required String authorId,
    required String loginId,
    required String profileImageUrl,
    required String content,
    required String commentId,
    required int likeCount,
    required bool isLiked,
    required bool isAuthor,
    String? commentImgUrl,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: profileImageUrl.isNotEmpty
                    ? NetworkImage(profileImageUrl)
                    : null,
                child: profileImageUrl.isEmpty ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 12),
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
                      '@$loginId',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      content,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              if (isAuthor)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editComment(commentId, content);
                    } else if (value == 'delete') {
                      _deleteComment(commentId);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('수정'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('삭제'),
                    ),
                  ],
                ),
              Column(
                children: [
                  IconButton(
                    onPressed: () => _toggleLike(commentId, isLiked),
                    icon: Icon(
                      isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                      color: isLiked ? Colors.black : Colors.black,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  if (likeCount > 0)
                    Text(
                      '$likeCount',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ],
          ),
          // 댓글 이미지
          if (commentImgUrl != null && commentImgUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 300,
                height: 300,
                child: Image.network(
                  commentImgUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
