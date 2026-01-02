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
  final FirebaseAuth auth = FirebaseAuth.instance;

  late String userId;
  late String nickname;

  List<Map<String, dynamic>> questions = [];

  bool isLoading = true;
  String errorMessage = '';

  /// 로그인 유저 정보
  Future<void> _loadUserInfo() async {
    final user = auth.currentUser;
    if (user == null) return;

    userId = user.uid;

    final userDoc = await fs.collection('users').doc(userId).get();
    nickname = userDoc.data()?['nickname'] ?? 'Unknown';
  }

  /// Questions 로드
  Future<void> _getQuestions() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      await _loadUserInfo();

      final snapshot = await fs
          .collection('questions')
          .orderBy('createdAt', descending: true)
          .get();

      questions = await Future.wait(snapshot.docs.map((doc) async {
        final data = doc.data();
        final docId = doc.id;
        final String authorId = data['authorId'] ?? '';

        String authorNickname = 'Unknown';
        String profileImageUrl = '';

        if (authorId.isNotEmpty) {
          final userDoc = await fs.collection('users').doc(authorId).get();
          authorNickname = userDoc.data()?['nickname'] ?? 'Unknown';
          profileImageUrl = userDoc.data()?['profileImageUrl'] ?? '';
        }

        final likesSnapshot = await fs
            .collection('questions')
            .doc(docId)
            .collection('likes')
            .get();

        final bool isLiked = likesSnapshot.docs.any((doc) => doc.id == userId);

        return {
          'docId': docId,
          'authorId': authorId,
          'authorNickname': authorNickname,
          'authorProfileImageUrl': profileImageUrl,
          'text': data['text'] ?? '',
          'imageUrl': data['imageUrl'] ?? '',
          'commentCount': data['commentCount'] ?? 0,
          'likeCount': likesSnapshot.size,
          'isLiked': isLiked,
        };
      }).toList());

      setState(() => isLoading = false);
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = '데이터를 불러오는 중 오류 발생';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _getQuestions();
  }

  @override
  Widget build(BuildContext context) {
    final String currentPath = GoRouterState.of(context).uri.path;

    return Container(
      color: Colors.white,
      child: SafeArea(
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
                  else if (errorMessage.isNotEmpty)
                    Center(child: Text(errorMessage))
                  else if (questions.isEmpty)
                      const Center(child: Text('게시글이 없습니다'))
                    else
                      ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: questions.length,
                        itemBuilder: (context, index) {
                          return _questionItem(questions[index]);
                        },
                      ),

                  /// 글쓰기 버튼 (반투명 스타일)
                  Positioned(
                    bottom: 25,
                    right: 30,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => context.go('/questionAdd'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCAD83B).withOpacity(0.85),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'post a look',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
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

  /// Question Item
  Widget _questionItem(Map<String, dynamic> item) {
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
          /// ⭐ 프로필 클릭 시 해당 작성자의 userId를 쿼리 파라미터로 전달
          ListTile(
            onTap: () {
              context.go('/publicWardrobe?userId=${item['authorId']}');
            },
            leading: CircleAvatar(
              backgroundImage: item['authorProfileImageUrl'].isNotEmpty
                  ? NetworkImage(item['authorProfileImageUrl'])
                  : null,
              child: item['authorProfileImageUrl'].isEmpty
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(
              item['authorNickname'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('@${item['authorId']}'),
            trailing: IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () => _showPostOptionsMenu(
                item['docId'],
                item['authorId'],
                item['text'],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              item['text'],
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          if (item['imageUrl'] != null && item['imageUrl'].isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  item['imageUrl'],
                  height: 280,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 280,
                    child: Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                InkWell(
                  onTap: () => _toggleLike(item),
                  child: Row(
                    children: [
                      Icon(
                        item['isLiked']
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: item['isLiked'] ? Colors.red : Colors.black,
                      ),
                      const SizedBox(width: 6),
                      Text(item['likeCount'].toString()),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                InkWell(
                  onTap: () {
                    context.go('/questionComment', extra: {
                      'postId': item['docId'],
                      'authorId': item['authorId'],
                    });
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline),
                      const SizedBox(width: 6),
                      Text(item['commentCount'].toString()),
                    ],
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => _showShareOptions(
                    context,
                    item['text'],
                    item['imageUrl'],
                  ),
                  child: const Icon(Icons.share_outlined),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ❤️ 좋아요 토글
  Future<void> _toggleLike(Map<String, dynamic> item) async {
    final docId = item['docId'];

    final likeRef =
    fs.collection('questions').doc(docId).collection('likes').doc(userId);

    setState(() {
      if (item['isLiked']) {
        item['isLiked'] = false;
        item['likeCount']--;
      } else {
        item['isLiked'] = true;
        item['likeCount']++;
      }
    });

    try {
      if (item['isLiked']) {
        await likeRef.set({'likedAt': FieldValue.serverTimestamp()});
      } else {
        await likeRef.delete();
      }
    } catch (e) {
      setState(() {
        if (item['isLiked']) {
          item['isLiked'] = false;
          item['likeCount']--;
        } else {
          item['isLiked'] = true;
          item['likeCount']++;
        }
      });
    }
  }

  /// 수정 / 삭제
  void _showPostOptionsMenu(String postId, String authorId, String content) {
    if (authorId != userId) return;

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
                      _editPost(postId, content);
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
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(bottomSheetContext);
                      try {
                        await fs.collection('questions').doc(postId).delete();
                        if (mounted) {
                          _getQuestions();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('삭제 중 오류가 발생했습니다')),
                          );
                        }
                      }
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
          ),
        );
      },
    );
  }

  void _editPost(String postId, String content) {
    final controller = TextEditingController(text: content);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('질문 수정'),
        content: TextField(controller: controller, maxLines: 5),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final newText = controller.text.trim();
              Navigator.pop(dialogContext);

              if (newText.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('내용을 입력해주세요')),
                  );
                }
                return;
              }

              try {
                await fs
                    .collection('questions')
                    .doc(postId)
                    .update({'text': newText});

                if (mounted) {
                  _getQuestions();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('수정 중 오류가 발생했습니다')),
                  );
                }
              }
            },
            child: const Text('수정'),
          ),
        ],
      ),
    );
  }

  /// 공유 관련
  void _showShareOptions(
      BuildContext context, String content, String imageUrl) {
    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.chat),
                title: const Text('카카오톡'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _shareToKakao(content, imageUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('인스타그램'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _shareToInstagram(imageUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.facebook),
                title: const Text('페이스북'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _shareToFacebook(imageUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('기타'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  Share.share('$content\n\n$imageUrl');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareToKakao(String content, String imageUrl) async {
    try {
      final template = FeedTemplate(
        content: Content(
          title: 'Question',
          description: content,
          imageUrl: Uri.parse(imageUrl),
          link: Link(
            webUrl: Uri.parse('https://www.example.com'),
            mobileWebUrl: Uri.parse('https://www.example.com'),
          ),
        ),
      );

      final url =
      await WebSharerClient.instance.makeDefaultUrl(template: template);
      await launchUrl(url);
    } catch (e) {
      debugPrint('Kakao share error: $e');
    }
  }

  Future<void> _shareToInstagram(String imageUrl) async {
    try {
      final uri = Uri.parse('instagram://library?AssetPath=$imageUrl');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Instagram share error: $e');
    }
  }

  Future<void> _shareToFacebook(String imageUrl) async {
    try {
      final uri =
      Uri.parse('https://www.facebook.com/sharer/sharer.php?u=$imageUrl');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Facebook share error: $e');
    }
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
}