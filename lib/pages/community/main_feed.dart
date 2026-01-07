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
          .orderBy('createdAt', descending: true)
          .get();

      lookbooks = await Future.wait(snapshot.docs.map((doc) async {
        final data = doc.data();
        final docId = doc.id;
        final String authorId = data['userId'] ?? '';

        String authorNickname = 'Unknown';
        String profileImageUrl = '';
        String authorLoginId = '';

        if (authorId.isNotEmpty) {
          final userDoc =
          await fs.collection('users').doc(authorId).get();
          authorNickname = userDoc.data()?['nickname'] ?? 'Unknown';
          profileImageUrl =
              userDoc.data()?['profileImageUrl'] ?? '';
          authorLoginId =
              userDoc.data()?['loginId'] ?? userDoc.data()?['email'] ?? '';
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
          'authorLoginId': authorLoginId,
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
    const int selectedIndex = 0;
    final String currentPath = GoRouterState
        .of(context)
        .uri
        .path;

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: _SleekTopTabs(
                selectedIndex: selectedIndex,
                onTapCloset: () => context.go('/communityMainFeed'),
                onTapLookbooks: () => context.go('/questionFeed'),
                onTapScrap: () => context.go('/followList'),
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
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text('@${item['authorLoginId']}'),
            // 신고 버튼 (자신의 게시물이 아닐 때만 표시)
            trailing: item['authorId'] != userId
                ? IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () =>
                  _showReportBottomSheet(
                    item['docId'],
                    item['authorId'],
                  ),
            )
                : null,
          ),

          //  이미지 - 탭하면 전체 화면으로
          if (item['resultImageUrl'] != null &&
              item['resultImageUrl'].isNotEmpty)
            GestureDetector(
              onTap: () =>
                  _showFullScreenImage(context, item['resultImageUrl']),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300, width: 1),
                    bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                child: Hero(
                  tag: item['resultImageUrl'],
                  child: Image.network(
                    item['resultImageUrl'],
                    height: 280,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                    const SizedBox(
                      height: 280,
                      child: Center(child: Icon(Icons.broken_image)),
                    ),
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
                  onTap: () =>
                      _showShareOptions(
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

  /// 전체 화면 이미지 보기
  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            Scaffold(
              backgroundColor: Colors.black,
              body: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Center(
                  child: Hero(
                    tag: imageUrl,
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
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

  /// 신고 바텀시트
  void _showReportBottomSheet(String postId, String authorId) {
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
                _showReportDialog(postId, authorId);
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
                'report',
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
  void _showReportDialog(String postId, String authorId) {
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
                  '게시글 신고',
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
                        // 신고 사유 선택
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
                        // 상세 내용 입력
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
                            'cancel',
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
                              postId,
                              authorId,
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
                            'report',
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
  Future<void> _submitReport(String postId,
      String reportedUserId,
      String reason,
      String detail,) async {
    try {
      // reports 컬렉션에 신고 내용 저장
      await fs.collection('reports').add({
        'type': 'lookbook', // 게시글 타입
        'postId': postId,
        'reporterId': userId, // 신고자
        'reportedUserId': reportedUserId, // 신고당한 사람
        'reason': reason,
        'detail': detail,
        'status': 'pending', // 처리 상태: pending, reviewed, resolved
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('신고가 접수되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('신고 접수 중 오류가 발생했습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 공유 관련
  void _showShareOptions(BuildContext context, String content,
      String imageUrl) {
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
}
class _SleekTopTabs extends StatelessWidget {
  const _SleekTopTabs({
    required this.selectedIndex,
    required this.onTapCloset,
    required this.onTapLookbooks,
    required this.onTapScrap,
  });

  final int selectedIndex;
  final VoidCallback onTapCloset;
  final VoidCallback onTapLookbooks;
  final VoidCallback onTapScrap;

  Alignment _indicatorAlign() {
    if (selectedIndex == 0) return Alignment.centerLeft;
    if (selectedIndex == 1) return Alignment.center;
    return Alignment.centerRight;
  }

  @override
  Widget build(BuildContext context) {
    const double height = 50;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, c) {
          final double w = c.maxWidth;
          final double segmentW = w / 3;

          return Stack(
            children: [
              // 바탕(테두리만)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 1.2),
                  borderRadius: BorderRadius.circular(26),
                ),
              ),

              // 선택 인디케이터(슬라이드)
              AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: _indicatorAlign(),
                child: Container(
                  width: segmentW,
                  height: height,
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFCAD83B), // 기존 감성 유지
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.black, width: 1.2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 탭 버튼들
              Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      selected: selectedIndex == 0,
                      icon: Icons.feed_outlined,
                      label: 'Feed',
                      onTap: onTapCloset,
                    ),
                  ),
                  Expanded(
                    child: _TabButton(
                      selected: selectedIndex == 1,
                      icon: Icons.question_answer,
                      label: 'QnA',
                      onTap: onTapLookbooks,
                    ),
                  ),
                  Expanded(
                    child: _TabButton(
                      selected: selectedIndex == 2,
                      icon: Icons.face,
                      label: 'Follow',
                      onTap: onTapScrap,
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
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextStyle textStyle = TextStyle(
      fontWeight: FontWeight.w900,
      fontSize: 17,
      color: Colors.black,
      letterSpacing: 0.2,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        splashColor: Colors.black.withOpacity(0.05),
        highlightColor: Colors.black.withOpacity(0.03),
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: selected ? 1.0 : 0.85,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: Colors.black),
                const SizedBox(width: 6),
                Text(label, style: textStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
