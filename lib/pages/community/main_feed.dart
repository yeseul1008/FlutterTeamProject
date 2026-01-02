import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:url_launcher/url_launcher.dart';

class CommunityMainFeed extends StatefulWidget {
  const CommunityMainFeed({super.key});

  @override
  State<CommunityMainFeed> createState() => _CommunityMainFeedState();
}

class _CommunityMainFeedState extends State<CommunityMainFeed> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  late String userId;
  late String nickname;

  List<Map<String, dynamic>> lookbooks = [];

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

  /// Lookbooks 로드
  Future<void> _getLookbooks() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      await _loadUserInfo();

      final snapshot = await fs
          .collection('lookbooks')
          .where('publishToCommunity', isEqualTo: true)
          .get();

      lookbooks = await Future.wait(snapshot.docs.map((doc) async {
        final data = doc.data();
        final docId = doc.id;
        final String authorId = data['userId'] ?? '';

        String authorNickname = 'Unknown';
        String profileImageUrl = '';

        if (authorId.isNotEmpty) {
          final userDoc =
          await fs.collection('users').doc(authorId).get();
          authorNickname = userDoc.data()?['nickname'] ?? 'Unknown';
          profileImageUrl =
              userDoc.data()?['profileImageUrl'] ?? '';
        }

        final likesSnapshot = await fs
            .collection('lookbooks')
            .doc(docId)
            .collection('likes')
            .get();

        final bool isLiked =
        likesSnapshot.docs.any((doc) => doc.id == userId);

        return {
          'docId': docId,
          'authorId': authorId,
          'authorNickname': authorNickname,
          'authorProfileImageUrl': profileImageUrl,
          'resultImageUrl': data['resultImageUrl'],
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
    _getLookbooks();
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
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage.isNotEmpty
                  ? Center(child: Text(errorMessage))
                  : lookbooks.isEmpty
                  ? const Center(child: Text('게시글이 없습니다'))
                  : ListView.builder(
                padding:
                const EdgeInsets.fromLTRB(16, 0, 16, 100),
                itemCount: lookbooks.length,
                itemBuilder: (context, index) {
                  return _lookbookItem(lookbooks[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lookbook Item
  Widget _lookbookItem(Map<String, dynamic> item) {
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
          ///  프로필 클릭 시 해당 작성자의 userId를 쿼리 파라미터로 전달
          ListTile(
            onTap: () {
              context.go('/publicLookBook?userId=${item['authorId']}');
            },
            leading: CircleAvatar(
              backgroundImage:
              item['authorProfileImageUrl'].isNotEmpty
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
          ),

          //  이미지 - 양옆 테두리까지 꽉 차게
          if (item['resultImageUrl'] != null &&
              item['resultImageUrl'].isNotEmpty)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300, width: 1),
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
              child: Image.network(
                item['resultImageUrl'],
                height: 280,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                  height: 280,
                  child: Center(child: Icon(Icons.broken_image)),
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
                        color: item['isLiked']
                            ? Colors.red
                            : Colors.black,
                      ),
                      const SizedBox(width: 6),
                      Text(item['likeCount'].toString()),
                    ],
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => _showShareOptions(
                    context,
                    item['authorNickname'],
                    item['resultImageUrl'],
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

  /// ❤️ 좋아요 토글 (users/{userId}/scraps 추가 포함)
  Future<void> _toggleLike(Map<String, dynamic> item) async {
    final docId = item['docId'];

    final likeRef = fs
        .collection('lookbooks')
        .doc(docId)
        .collection('likes')
        .doc(userId);

    // users/{userId}/scraps/{scrapId} 구조
    final scrapRef = fs
        .collection('users')
        .doc(userId)
        .collection('scraps')
        .doc(docId);

    // UI 먼저 업데이트
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
        // 좋아요 추가
        await likeRef.set({'likedAt': FieldValue.serverTimestamp()});

        // users/{userId}/scraps에도 추가
        await scrapRef.set({
          'feedId': docId,
          'scrapedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // 좋아요 제거
        await likeRef.delete();

        // users/{userId}/scraps에서도 제거
        await scrapRef.delete();
      }
    } catch (e) {
      // 오류 발생 시 롤백
      setState(() {
        if (item['isLiked']) {
          item['isLiked'] = false;
          item['likeCount']--;
        } else {
          item['isLiked'] = true;
          item['likeCount']++;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('좋아요 처리 중 오류가 발생했습니다')),
        );
      }
    }
  }

  /// 공유 관련
  void _showShareOptions(
      BuildContext context, String content, String imageUrl) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
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
                  _shareToFacebook(imageUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('기타'),
                onTap: () {
                  Navigator.pop(context);
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
    final template = FeedTemplate(
      content: Content(
        title: 'Lookbook',
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
  }

  Future<void> _shareToInstagram(String imageUrl) async {
    final uri = Uri.parse('instagram://library?AssetPath=$imageUrl');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _shareToFacebook(String imageUrl) async {
    final uri = Uri.parse(
        'https://www.facebook.com/sharer/sharer.php?u=$imageUrl');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
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
                fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
      ),
    );
  }
}