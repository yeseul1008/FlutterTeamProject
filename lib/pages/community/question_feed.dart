import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Tutorial keys
  final GlobalKey _tabsKey = GlobalKey();
  final GlobalKey _postButtonKey = GlobalKey();
  final GlobalKey _likeKey = GlobalKey();
  final GlobalKey _commentKey = GlobalKey();
  final GlobalKey _shareKey = GlobalKey();

  TutorialCoachMark? tutorialCoachMark;

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
        String authorLoginId = '';
        String profileImageUrl = '';

        if (authorId.isNotEmpty) {
          final userDoc = await fs.collection('users').doc(authorId).get();
          authorNickname = userDoc.data()?['nickname'] ?? 'Unknown';
          authorLoginId = userDoc.data()?['loginId'] ?? '';
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
          'authorLoginId': authorLoginId,
          'authorProfileImageUrl': profileImageUrl,
          'text': data['text'] ?? '',
          'imageUrl': data['imageUrl'] ?? '',
          'resultImageUrl': data['resultImageUrl'] ?? '',
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

  // Check if this is the user's first time
  Future<void> _checkAndShowTutorial() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasSeenTutorial = prefs.getBool('hasSeenQuestionFeedTutorial') ?? false;

    if (!hasSeenTutorial && questions.isNotEmpty) {
      Future.delayed(Duration(milliseconds: 800), () {
        if (mounted) {
          _showTutorial();
          prefs.setBool('hasSeenQuestionFeedTutorial', true);
        }
      });
    }
  }

  void _createTutorial() {
    tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Colors.black,
      textSkip: "Skip",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        debugPrint("Tutorial finished");
      },
      onClickTarget: (target) {
        debugPrint('Clicked on ${target.identify}');
      },
      onSkip: () {
        debugPrint("Tutorial skipped");
        return true;
      },
    );
  }

  List<TargetFocus> _createTargets() {
    List<TargetFocus> targets = [];

    // Target 1: Tab Buttons
    targets.add(
      TargetFocus(
        identify: "tabs",
        keyTarget: _tabsKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 30,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "탭 메뉴",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Feed, QnA, Follow 탭을 전환할 수 있습니다",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );

    // Target 2: Post Button
    targets.add(
      TargetFocus(
        identify: "post-button",
        keyTarget: _postButtonKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 30,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.edit, color: Color(0xFFCAD83B), size: 40),
                    SizedBox(height: 10),
                    Text(
                      "새 게시글 작성",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "여기를 탭해서 새로운 패션 질문을 작성하세요!",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );

    // Target 3: Like Button (if questions exist)
    if (questions.isNotEmpty) {
      targets.add(
        TargetFocus(
          identify: "like",
          keyTarget: _likeKey,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.Circle,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return Container(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.favorite, color: Colors.red, size: 40),
                      SizedBox(height: 10),
                      Text(
                        "좋아요",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 20.0,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "마음에 드는 게시글에 좋아요를 눌러보세요",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );

      // Target 4: Comment Button
      targets.add(
        TargetFocus(
          identify: "comment",
          keyTarget: _commentKey,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.Circle,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return Container(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.chat_outlined,
                          color: Color(0xFFCAD83B), size: 40),
                      SizedBox(height: 10),
                      Text(
                        "댓글",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 20.0,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "댓글을 작성하여 의견을 나눠보세요",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );

      // Target 5: Share Button
      targets.add(
        TargetFocus(
          identify: "share",
          keyTarget: _shareKey,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.Circle,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return Container(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.share_outlined,
                          color: Color(0xFFCAD83B), size: 40),
                      SizedBox(height: 10),
                      Text(
                        "공유하기",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 20.0,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "게시글을 SNS에 공유할 수 있습니다",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    return targets;
  }

  void _showTutorial() {
    _createTutorial();
    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted && tutorialCoachMark != null) {
        tutorialCoachMark?.show(context: context);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _getQuestions().then((_) {
      _checkAndShowTutorial();
    });
  }

  @override
  Widget build(BuildContext context) {
    const int selectedIndex = 1;

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // 탭에 key 연결
            Padding(
              key: _tabsKey,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: _SleekTopTabs(
                selectedIndex: selectedIndex,
                onTapCloset: () => context.go('/communityMainFeed'),
                onTapLookbooks: () => context.go('/questionFeed'),
                onTapScrap: () => context.go('/followList'),
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
                          return _questionItem(questions[index], index);
                        },
                      ),

                  /// 글쓰기 버튼 (반투명 스타일)
                  Positioned(
                    bottom: 25,
                    right: 30,
                    child: Container(
                      key: _postButtonKey,
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
                          backgroundColor:
                          const Color(0xFFCAD83B).withOpacity(0.85),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Post a Look',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 18),
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
  Widget _questionItem(Map<String, dynamic> item, int index) {
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
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text('@${item['authorLoginId']}'),
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

          // 일반 이미지 - 탭하면 전체 화면으로
          if (item['imageUrl'] != null && item['imageUrl'].isNotEmpty)
            GestureDetector(
              onTap: () => _showFullScreenImage(
                  context, item['imageUrl'], item['docId'], true),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Hero(
                    tag: 'image_${item['docId']}',
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
              ),
            ),

          // 결과 이미지 - 탭하면 전체 화면으로
          if (item['resultImageUrl'] != null &&
              item['resultImageUrl'].isNotEmpty)
            GestureDetector(
              onTap: () => _showFullScreenImage(
                  context, item['resultImageUrl'], item['docId'], false),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300, width: 1),
                    bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                child: Hero(
                  tag: 'result_${item['docId']}',
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
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                InkWell(
                  key: index == 0 ? _likeKey : null,
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
                  key: index == 0 ? _commentKey : null,
                  onTap: () {
                    context.go('/questionComment', extra: {
                      'postId': item['docId'],
                      'authorId': item['authorId'],
                    });
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.chat_outlined),
                      const SizedBox(width: 6),
                      Text(item['commentCount'].toString()),
                    ],
                  ),
                ),
                const Spacer(),
                InkWell(
                  key: index == 0 ? _shareKey : null,
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

  /// 전체 화면 이미지 보기
  void _showFullScreenImage(
      BuildContext context, String imageUrl, String docId, bool isMainImage) {
    final heroTag = isMainImage ? 'image_$docId' : 'result_$docId';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Center(
              child: Hero(
                tag: heroTag,
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

  /// 게시글 옵션 메뉴 (수정/삭제 또는 신고/튜토리얼)
  void _showPostOptionsMenu(String postId, String authorId, String content) {
    // 본인 게시글인 경우 - 수정/삭제/튜토리얼
    if (authorId == userId) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (bottomSheetContext) {
          return Container(
            margin: const EdgeInsets.all(16),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
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
                            _showDeleteConfirmDialog(postId);
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(bottomSheetContext);
                        _showTutorial();
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
    } else {
      // 타인 게시글인 경우 - 신고/튜토리얼 (좌우로 배치)
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
                        _showTutorial();
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
      builder: (dialogContext) => StatefulBuilder(
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
                        'Cancel',
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
                        'Report',
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
  Future<void> _submitReport(
      String postId,
      String reportedUserId,
      String reason,
      String detail,
      ) async {
    try {
      await fs.collection('reports').add({
        'type': 'question',
        'postId': postId,
        'reporterId': userId,
        'reportedUserId': reportedUserId,
        'reason': reason,
        'detail': detail,
        'status': 'pending',
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

  /// 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog(String postId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
                    'Cancel',
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
                      await fs.collection('questions').doc(postId).delete();
                      if (mounted) {
                        _getQuestions();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('게시글이 삭제되었습니다')),
                        );
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
                    backgroundColor: const Color(0xFFCAD83B),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Delete',
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

  void _editPost(String postId, String content) async {
    final doc = await fs.collection('questions').doc(postId).get();
    final data = doc.data();

    final controller = TextEditingController(text: content);
    String currentImageUrl = data?['imageUrl'] ?? '';

    File? newImageFile;

    final ImagePicker picker = ImagePicker();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
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
              '질문 수정',
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
                    TextField(
                      controller: controller,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: '질문을 입력하세요...',
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
                    const SizedBox(height: 16),
                    const Text(
                      '이미지',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (newImageFile != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              newImageFile!,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setDialogState(() => newImageFile = null);
                                },
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (currentImageUrl.isNotEmpty)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              currentImageUrl,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child:
                                const Icon(Icons.broken_image, size: 40),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setDialogState(() => currentImageUrl = '');
                                },
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.grey[300]!, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            '이미지 없음',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final XFile? pickedFile = await picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (pickedFile != null) {
                            setDialogState(() {
                              newImageFile = File(pickedFile.path);
                            });
                          }
                        },
                        icon: const Icon(Icons.photo_library, size: 20),
                        label: const Text(
                          '이미지 변경',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: BorderSide(color: Colors.grey[400]!),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
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
                          String? uploadedImageUrl = currentImageUrl.isNotEmpty
                              ? currentImageUrl
                              : null;

                          if (newImageFile != null) {
                            final ref = FirebaseStorage.instance
                                .ref()
                                .child(
                                'questions/${postId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
                            await ref.putFile(newImageFile!);
                            uploadedImageUrl = await ref.getDownloadURL();
                          }

                          await fs.collection('questions').doc(postId).update({
                            'text': newText,
                            'imageUrl': uploadedImageUrl ?? '',
                          });

                          if (mounted) {
                            _getQuestions();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('수정이 완료되었습니다')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('수정 중 오류가 발생했습니다')),
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
                        'save',
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
      final uri = Uri.parse(
          'https://www.facebook.com/sharer/sharer.php?u=$imageUrl');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Facebook share error: $e');
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
                      color: const Color(0xFFCAD83B),
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