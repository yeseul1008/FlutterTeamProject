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
  bool isLiked = false;
  int likeCount = 0;
  List<String> likedUserNicknames = [];
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

      if (qnaPostSnapshot.docs.isNotEmpty) {
        setState(() {
          qnaPost = qnaPostSnapshot.docs.first.data();
          qnaPostId = qnaPostSnapshot.docs.first.id;

          likeCount = qnaPost['likeCount'] ?? 0;
          List<dynamic> likedUsers = qnaPost['likedUsers'] ?? [];
          isLiked = likedUsers.any((user) => user['userId'] == userId);
          likedUserNicknames = likedUsers.map((user) => user['nickname'].toString()).toList();

          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = '게시글이 없습니다';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = '데이터를 불러오는 중 오류가 발생했습니다: $e';
      });
    }
  }

  Future<void> _toggleLike() async {
    if (qnaPostId.isEmpty) return;

    final docRef = fs.collection('qna_posts').doc(qnaPostId);

    try {
      await fs.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) return;

        List<dynamic> likedUsers = List.from(snapshot.data()?['likedUsers'] ?? []);
        int currentLikeCount = snapshot.data()?['likeCount'] ?? 0;

        final userIndex = likedUsers.indexWhere((user) => user['userId'] == userId);

        if (userIndex >= 0) {
          likedUsers.removeAt(userIndex);
          currentLikeCount = (currentLikeCount - 1).clamp(0, double.infinity).toInt();
        } else {
          likedUsers.add({
            'userId': userId,
            'nickname': nickname,
          });
          currentLikeCount++;
        }

        transaction.update(docRef, {
          'likedUsers': likedUsers,
          'likeCount': currentLikeCount,
        });
      });

      await _getQnaPost();
    } catch (e) {
      print('Error toggling like: $e');
    }
  }

  void _showLikedUsersDialog() {
    if (likedUserNicknames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아직 좋아요를 누른 사람이 없습니다')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('좋아요를 누른 사람'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: likedUserNicknames.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(likedUserNicknames[index]),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  void _showPostOptionsMenu(String postAuthorId) {
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

          /// ===== Feed Body =====
          Expanded(
            child: Stack(
              children: [
                isLoading
                    ? Center(child: CircularProgressIndicator())
                    : errorMessage.isNotEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        errorMessage,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _getQnaPost,
                        child: Text('다시 시도'),
                      ),
                    ],
                  ),
                )
                    : qnaPost.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 100),
                  children: [
                    _qnaItem(
                      nickname: qnaPost['nickname'] ?? nickname,
                      authorId: qnaPost['authorId'] ?? userId,
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
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    context.push('/publicLookBook', extra: {
                      'userId': authorId,
                      'nickname': nickname,
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Icon(Icons.person, color: Colors.grey),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () {
                          context.push('/publicWardrobe', extra: {
                            'userId': authorId,
                            'nickname': nickname,
                          });
                        },
                        child: Text(
                          nickname,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
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
                IconButton(
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () => _showPostOptionsMenu(authorId),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          if (qnaPost['content'] != null && qnaPost['content'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                qnaPost['content'],
                style: TextStyle(fontSize: 14),
              ),
            ),
          const SizedBox(height: 12),
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
                      child: Icon(Icons.image_not_supported,
                          size: 50, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                InkWell(
                  onTap: _toggleLike,
                  child: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color: isLiked ? Colors.red : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _showLikedUsersDialog,
                  child: Text(
                    likeCount.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
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
}
