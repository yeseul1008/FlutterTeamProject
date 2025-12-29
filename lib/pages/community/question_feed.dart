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
  String qnaPostId = '';
  // 로딩 상태 관리
  bool isLoading = true;
  String errorMessage = '';

  Future<void> _getQnaPost() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // where 조건 제거하고 모든 문서 가져오기 (테스트용)
      final qnaPostSnapshot = await fs
          .collection('qna_posts')
          .limit(1) // 첫 번째 문서만 가져오기
          .get();

      print('Number of documents found: ${qnaPostSnapshot.docs.length}');

      if (qnaPostSnapshot.docs.isNotEmpty) {
        setState(() {
          qnaPost = qnaPostSnapshot.docs.first.data();
          qnaPostId = qnaPostSnapshot.docs.first.id;
          print('Post data: $qnaPost');
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = '게시글이 없습니다';
        });
      }
    } catch (e) {
      print('Error getting post: $e');
      setState(() {
        isLoading = false;
        errorMessage = '데이터를 불러오는 중 오류가 발생했습니다: $e';
      });
    }
  }

  // ✅ 수정: 게시글 옵션 메뉴 - 다이얼로그 스타일로 변경
  void _showPostOptionsMenu(String postAuthorId) {
    // ✅ 테스트용: 작성자 확인 비활성화 (주석 처리)
    // String actualAuthorId = qnaPost['authorId'] ?? '';
    // if (actualAuthorId != userId) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('본인의 게시글만 수정/삭제할 수 있습니다')),
    //   );
    //   return;
    // }

    // 실제 배포 시에는 위 주석을 해제하고 아래를 삭제하세요

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Edit 버튼
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _editPost();
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
                        'edit',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Delete 버튼
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deletePost();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB19FFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'delete',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 게시글 수정 함수
  void _editPost() {
    showDialog(
      context: context,
      builder: (context) {
        final contentController = TextEditingController(text: qnaPost['content']);

        return AlertDialog(
          title: const Text('게시글 수정'),
          content: TextField(
            controller: contentController,
            decoration: const InputDecoration(
              hintText: '내용을 입력하세요',
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                if (contentController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('내용을 입력해주세요')),
                  );
                  return;
                }

                try {
                  await fs.collection('qna_posts').doc(qnaPostId).update({
                    'content': contentController.text.trim(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('게시글이 수정되었습니다')),
                  );
                  await _getQnaPost();
                } catch (e) {
                  print('Error updating post: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('수정 중 오류가 발생했습니다')),
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

  // 게시글 삭제 함수
  void _deletePost() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('게시글 삭제'),
        content: const Text('정말로 이 게시글을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await fs.collection('qna_posts').doc(qnaPostId).delete();

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('게시글이 삭제되었습니다')),
                );

                setState(() {
                  qnaPost = {};
                  qnaPostId = '';
                });

                await _getQnaPost();
              } catch (e) {
                print('Error deleting post: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('삭제 중 오류가 발생했습니다')),
                );
              }
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
                // 로딩, 에러, 데이터 없음 상태 처리
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : errorMessage.isNotEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 60, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _getQnaPost,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
                    : qnaPost.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.article_outlined, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        '게시글이 없습니다',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
                    : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  children: [
                    _qnaItem(
                      nickname: qnaPost['nickname'] ?? nickname,
                      authorId: qnaPost['authorId'] ?? userId,
                      imageUrl: qnaPost['imageUrl'] ?? '',
                      commentCount: qnaPost['commentCount'] ?? 0,
                      postId: qnaPostId,
                    ),
                  ],
                ),

                // post a look 버튼
                Positioned(
                  bottom: 25,
                  right: 30,
                  child: ElevatedButton(
                    onPressed: () {
                      context.go('/questionAdd');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCAD83B),
                      foregroundColor: Colors.black,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
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

  /// ===== QnA 카드 UI =====
  Widget _qnaItem({
    required String nickname,
    required String authorId,
    required String imageUrl,
    required int commentCount,
    required String postId,
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
                // 더보기 버튼 클릭 시 옵션 메뉴 표시
                IconButton(
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () => _showPostOptionsMenu(authorId),
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
                errorBuilder: (_, __, ___) =>
                const Icon(Icons.image_not_supported),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                // 댓글 아이콘 - 클릭 시 댓글 페이지로 이동
                InkWell(
                  onTap: () {
                    context.go('/questionComment', extra: {
                      'postId': postId,
                      'authorId': authorId,
                      'nickname': nickname,
                    });
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline),
                      const SizedBox(width: 6),
                      Text(commentCount.toString()),
                    ],
                  ),
                ),

                const Spacer(),

                // 공유하기 아이콘
                InkWell(
                  onTap: () {
                    // 공유하기 기능
                    Share.share(
                      '${qnaPost['content'] ?? '질문을 확인해보세요!'}\n\n이미지: $imageUrl',
                      subject: '$nickname님의 질문',
                    );
                  },
                  child: const Icon(Icons.share_outlined),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}