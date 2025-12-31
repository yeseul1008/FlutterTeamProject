import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:url_launcher/url_launcher.dart';

class QuestionFeed extends StatefulWidget {
  const QuestionFeed({super.key});

  @override
  State<QuestionFeed> createState() => _QuestionFeedState();
}

class _QuestionFeedState extends State<QuestionFeed> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  // FirebaseAuth에서 현재 로그인한 사용자 ID 가져오기
  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  List<QueryDocumentSnapshot<Map<String, dynamic>>> qnaPosts = [];
  bool isLoading = true;

  Future<void> _getQnaPost() async {
    try {
      // Firestore에서 질문들을 내림차순으로 가져옵니다.
      final snapshot = await fs
          .collection('questions')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        qnaPosts = snapshot.docs;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('QnA fetch error: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // 수정/삭제 모달 표시
  void _showPostOptionsMenu(String postId, String authorId, String currentContent) {
    // 작성자가 아니면 모달을 표시하지 않음
    if (authorId != currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('작성자만 수정/삭제할 수 있습니다')),
      );
      return;
    }

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
                        _editPost(postId, currentContent);
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
                        _deletePost(postId);
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

  // 게시글 수정
  void _editPost(String postId, String currentContent) {
    final TextEditingController contentController = TextEditingController(text: currentContent);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('질문 수정'),
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
                await fs.collection('questions').doc(postId).update({
                  'text': contentController.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('질문이 수정되었습니다')),
                );
                await _getQnaPost(); // 목록 새로고침
              } catch (e) {
                debugPrint('Error updating post: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('수정 중 오류가 발생했습니다')),
                );
              }
            },
            child: const Text('수정'),
          ),
        ],
      ),
    );
  }

  //  게시글 삭제
  void _deletePost(String postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('질문 삭제'),
        content: const Text('정말로 이 질문을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await fs.collection('questions').doc(postId).delete();

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('질문이 삭제되었습니다')),
                );
                await _getQnaPost(); // 목록 새로고침
              } catch (e) {
                debugPrint('Error deleting post: $e');
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
    _getQnaPost(); // 데이터 불러오기
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
                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (qnaPosts.isEmpty)
                  const Center(child: Text('게시글이 없습니다'))
                else
                  ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: qnaPosts.length,
                    itemBuilder: (context, index) {
                      final doc = qnaPosts[index];
                      final data = doc.data();

                      return _qnaItem(
                        postId: doc.id,
                        nickname: data['nickname'] ?? '',
                        authorId: data['authorId'] ?? '',
                        content: data['text'] ?? '',
                        imageUrl: data['imageUrl'] ?? '',
                        commentCount: data['commentCount'] ?? 0,
                      );
                    },
                  ),
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
      ),
    );
  }

  Widget _qnaItem({
    required String postId,
    required String nickname,
    required String authorId,
    required String content,
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
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nickname,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('@$authorId',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                // ... 버튼 (수정/삭제)
                IconButton(
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () => _showPostOptionsMenu(postId, authorId, content),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          Container(
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
                InkWell(
                  onTap: () {
                    debugPrint('🔵 공유 버튼 클릭됨');
                    _showShareOptions(context, content, imageUrl);
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

  // 공유 옵션 선택 다이얼로그
  void _showShareOptions(BuildContext context, String content, String imageUrl) {
    debugPrint('🔵 공유 옵션 다이얼로그 열림');

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.chat),
                title: const Text('카카오톡'),
                onTap: () {
                  debugPrint('🔵 카카오톡 메뉴 선택됨');
                  Navigator.pop(context);
                  _shareToKakao(content, imageUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('인스타그램'),
                onTap: () {
                  Navigator.pop(context);
                  _shareToInstagram(imageUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.facebook),
                title: const Text('페이스북'),
                onTap: () {
                  Navigator.pop(context);
                  _shareToFacebook(content, imageUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('기타'),
                onTap: () {
                  Navigator.pop(context);
                  _shareDefault(content, imageUrl);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 기본 공유 (share_plus)
  Future<void> _shareDefault(String content, String imageUrl) async {
    final shareContent = '$content\n\n$imageUrl';
    await Share.share(shareContent, subject: '질문 공유');
  }

  // 카카오톡 공유
  Future<void> _shareToKakao(String content, String imageUrl) async {
    try {
      debugPrint('=== 카카오 공유 시작 ===');
      final template = FeedTemplate(
        content: Content(
          title: '질문',
          description: content,
          imageUrl: Uri.parse(imageUrl),
          link: Link(
            webUrl: Uri.parse('https://www.example.com'),
            mobileWebUrl: Uri.parse('https://www.example.com'),
          ),
        ),
      );

      final sharerUrl = await WebSharerClient.instance.makeDefaultUrl(template: template);
      await launchUrl(sharerUrl);
      debugPrint('카카오 공유 완료');
    } catch (e) {
      debugPrint('카카오톡 공유 실패: $e');
    }
  }

  // 인스타그램 공유
  Future<void> _shareToInstagram(String imageUrl) async {
    final uri = Uri.parse('instagram://library?AssetPath=$imageUrl');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('인스타그램 앱이 설치되지 않았습니다.');
    }
  }

  // 페이스북 공유
  Future<void> _shareToFacebook(String content, String imageUrl) async {
    final uri = Uri.parse('https://www.facebook.com/sharer/sharer.php?u=$imageUrl');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('페이스북을 열 수 없습니다.');
    }
  }
}