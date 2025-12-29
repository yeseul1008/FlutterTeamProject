import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> qnaPosts = [];
  bool isLoading = true;

  Future<void> _getQnaPost() async {
    try {
      final snapshot = await fs
          .collection('qna_posts')
          .where('createdAt', isNull: false)
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
                        content: data['content'] ?? '',
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
      final template = FeedTemplate(
        content: Content(
          title: '외출 다이어리 질문',
          description: content,
          imageUrl: Uri.parse(imageUrl),
          link: Link(
            webUrl: Uri.parse('https://www.example.com'),
            mobileWebUrl: Uri.parse('https://www.example.com'),
          ),
        ),
      );

      final isKakaoTalkSharingAvailable =
      await ShareClient.instance.isKakaoTalkSharingAvailable();

      if (isKakaoTalkSharingAvailable) {
        await ShareClient.instance.shareDefault(template: template);
      } else {
        final sharerUrl = await WebSharerClient.instance
            .makeDefaultUrl(template: template);
        await launchUrl(sharerUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Kakao share error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카카오톡 공유에 실패했습니다')),
        );
      }
    }
  }

  // 인스타그램 공유
  Future<void> _shareToInstagram(String imageUrl) async {
    try {
      final uri = Uri.parse('instagram://library?AssetPath=$imageUrl');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('인스타그램 앱이 설치되어 있지 않습니다')),
          );
        }
      }
    } catch (e) {
      debugPrint('Instagram share error: $e');
    }
  }

  // 페이스북 공유
  Future<void> _shareToFacebook(String content, String imageUrl) async {
    try {
      final encodedUrl = Uri.encodeComponent(imageUrl);
      final uri = Uri.parse(
          'https://www.facebook.com/sharer/sharer.php?u=$encodedUrl');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('페이스북을 열 수 없습니다')),
          );
        }
      }
    } catch (e) {
      debugPrint('Facebook share error: $e');
    }
  }
}