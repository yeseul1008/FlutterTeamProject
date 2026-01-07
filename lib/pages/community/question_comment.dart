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
  late String postAuthorId;
  String currentUserId = '';
  int commentCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState
        .of(context)
        .extra as Map<String, dynamic>?;
    if (extra != null) {
      postId = extra['postId'];
      _loadPostAuthor();
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
          'commentImgUrl': data['commentImg'] ?? '',
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
    if (_commentController.text
        .trim()
        .isEmpty) return;

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

  /// 댓글 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog(String commentId) {
    showDialog(
      context: context,
      builder: (dialogContext) =>
          AlertDialog(
            backgroundColor: Colors.white,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            title: const Text(
              '삭제 확인',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            content: const Text(
              '삭제하시겠습니까?\n삭제 후에는 되돌릴 수 없습니다.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        try {
                          await fs
                              .collection('questions')
                              .doc(postId)
                              .collection('qna_comments')
                              .doc(commentId)
                              .delete();
                          _getComments();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('댓글이 삭제되었습니다')),
                            );
                          }
                        } catch (e) {
                          debugPrint('댓글 삭제 실패: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('삭제 중 오류가 발생했습니다')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCAD83B),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '삭제',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
  }

  /// 댓글 수정
  Future<void> _editComment(String commentId, String currentComment) async {
    final editController = TextEditingController(text: currentComment);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          title: const Text(
            '댓글 수정',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          content: TextField(
            controller: editController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '수정할 댓글 입력',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFCAD83B), width: 2),
              ),
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '취소',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (editController.text
                          .trim()
                          .isEmpty) return;
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
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('댓글이 수정되었습니다')),
                          );
                        }
                      } catch (e) {
                        debugPrint('댓글 수정 실패: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('댓글 수정 중 오류가 발생했습니다')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCAD83B),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '수정',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
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

  /// 신고 바텀시트
  void _showReportBottomSheet(String commentId, String commentAuthorId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          margin: const EdgeInsets.all(16),
          child: SafeArea(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(bottomSheetContext);
                _showReportDialog(commentId, commentAuthorId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Report',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 신고 다이얼로그
  void _showReportDialog(String commentId, String commentAuthorId) {
    String? selectedReason;
    final TextEditingController detailController = TextEditingController();

    final List<String> reportReasons = [
      '스팸/광고',
      '욕설/혐오 발언',
      '음란물',
      '허위 정보',
      '저작권 침해',
      '기타',
    ];

    showDialog(
      context: context,
      builder: (dialogContext) =>
          StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: Colors.white,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                title: const Text(
                  '댓글 신고',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '신고 사유를 선택해주세요',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...reportReasons.map((reason) {
                          return RadioListTile<String>(
                            title: Text(reason),
                            value: reason,
                            groupValue: selectedReason,
                            activeColor: const Color(0xFFCAD83B),
                            contentPadding: EdgeInsets.zero,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedReason = value;
                              });
                            },
                          );
                        }).toList(),
                        const SizedBox(height: 16),
                        TextField(
                          controller: detailController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: '상세 내용을 입력해주세요 (선택사항)',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFCAD83B),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: Colors.black),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '취소',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: selectedReason == null
                              ? null
                              : () async {
                            Navigator.pop(dialogContext);
                            await _submitReport(
                              commentId,
                              commentAuthorId,
                              selectedReason!,
                              detailController.text.trim(),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedReason == null
                                ? Colors.grey
                                : Colors.redAccent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '신고',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
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

  /// 신고 제출
  Future<void> _submitReport(String commentId,
      String reportedUserId,
      String reason,
      String detail,) async {
    // 현재 사용자 확인
    if (currentUserId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인이 필요합니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 자기 자신을 신고하는 경우 방지
    if (currentUserId == reportedUserId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('자신의 댓글은 신고할 수 없습니다'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // 이미 신고한 댓글인지 확인
      final existingReport = await fs
          .collection('reports')
          .where('type', isEqualTo: 'comment')
          .where('commentId', isEqualTo: commentId)
          .where('reporterId', isEqualTo: currentUserId)
          .get();

      if (existingReport.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이미 신고한 댓글입니다'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 신고 데이터 저장
      final reportData = {
        'type': 'comment',
        'postId': postId,
        'commentId': commentId,
        'reporterId': currentUserId,
        'reportedUserId': reportedUserId,
        'reason': reason,
        'detail': detail.isNotEmpty ? detail : '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'platform': 'qna', // QnA 댓글임을 명시
      };

      debugPrint('신고 데이터: $reportData');

      await fs.collection('reports').add(reportData);

      debugPrint('신고가 성공적으로 저장되었습니다');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('신고가 접수되었습니다. 검토 후 조치하겠습니다.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('신고 제출 실패: $e');
      debugPrint('에러 상세: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('신고 접수 중 오류가 발생했습니다: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentPath = GoRouterState
        .of(context)
        .uri
        .path;

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
                      fontWeight: FontWeight.w900,
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
                        fontWeight: FontWeight.w900,
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
                  GestureDetector(
                    onTap: () {
                      if (postAuthorId.isEmpty) return;

                      context.push(
                        '/questionCloset',
                        extra: {
                          'userId': postAuthorId,
                          'postId': postId,
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
                    onTap: () => _addComment(),
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
              fontWeight: FontWeight.w900,
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
                child:
                profileImageUrl.isEmpty ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
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
              // 작성자일 경우 수정/삭제, 아닐 경우 신고 메뉴
              IconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: () =>
                    _showCommentOptionsMenu(
                        commentId, authorId, content, isAuthor),
              ),
              Column(
                children: [
                  IconButton(
                    onPressed: () => _toggleLike(commentId, isLiked),
                    icon: Icon(
                      isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                      color: Colors.black,
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

  /// 댓글 옵션 메뉴 (수정/삭제 또는 신고)
  void _showCommentOptionsMenu(String commentId, String authorId,
      String content, bool isAuthor) {
    if (isAuthor) {
      // 본인 댓글인 경우 - 수정/삭제
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (bottomSheetContext) {
          return Container(
            margin: const EdgeInsets.all(16),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(bottomSheetContext);
                        _editComment(commentId, content);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCAD83B),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Edit',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(bottomSheetContext);
                        _showDeleteConfirmDialog(commentId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB39DDB),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      // 타인 댓글인 경우 - 신고 + 튜토리얼
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (bottomSheetContext) {
          return Container(
            margin: const EdgeInsets.all(16),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(bottomSheetContext);
                        _showReportDialog(commentId, authorId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Report',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(bottomSheetContext);
                        // 튜토리얼 기능이 있다면 여기에 추가
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('튜토리얼 기능은 준비 중입니다')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Tutorial',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }
}