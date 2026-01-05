import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserDiaryCards extends StatefulWidget {
  const UserDiaryCards({super.key});

  @override
  State<UserDiaryCards> createState() => _UserDiaryCardsState();
}

class _UserDiaryCardsState extends State<UserDiaryCards> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  // GlobalKeys for tutorial targets
  final GlobalKey _profileKey = GlobalKey();
  final GlobalKey _addDiaryKey = GlobalKey();
  final GlobalKey _diaryTabKey = GlobalKey();
  final GlobalKey _mapTabKey = GlobalKey();
  final GlobalKey _moreMenuKey = GlobalKey();

  TutorialCoachMark? tutorialCoachMark;

  Map<String, dynamic> userInfo = {};
  List<Map<String, dynamic>> userDiaries = [];
  int lookbookCnt = 0;
  int itemCnt = 0;
  int followerCnt = 0;
  File? selectedImage;
  bool isProcessingImage = false;
  String? profileImageUrl;

  String formatKoreanDate(Timestamp? timestamp) {
    if (timestamp == null) return '날짜 없음';
    final dt = timestamp.toDate();
    return '${dt.year}년 ${dt.month}월 ${dt.day}일';
  }

  Future<int> _getFollowerCount(String userId) async {
    try {
      final snapshot = await fs
          .collection('users')
          .doc(userId)
          .collection('followers')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting follower count: $e');
      return 0;
    }
  }

  Future<void> _getUserInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      if (!mounted) return;
      context.go('/userLogin');
      return;
    }

    final diariesSnapshot = await fs
        .collection('users')
        .doc(uid)
        .collection('diaries')
        .orderBy('createdAt', descending: true)
        .get();

    final lookbookSnapshot = await fs
        .collection('lookbooks')
        .where('userId', isEqualTo: uid)
        .get();

    final wardrobeSnapshot = await fs
        .collection('users')
        .doc(uid)
        .collection('wardrobe')
        .get();

    final userSnapshot = await fs.collection('users').doc(uid).get();
    final followerCount = await _getFollowerCount(uid);

    if (!mounted) return;
    setState(() {
      userInfo = userSnapshot.data() ?? {'userId': uid};
      lookbookCnt = lookbookSnapshot.docs.length;
      itemCnt = wardrobeSnapshot.docs.length;
      followerCnt = followerCount;
      userDiaries = diariesSnapshot.docs.map((doc) {
        final data = doc.data();
        data['diaryId'] = doc.id;
        data['formattedDate'] = formatKoreanDate(data['date']);
        return data;
      }).toList();
      profileImageUrl = userInfo['profileImageUrl'];
    });

    print('Number of diary entries: ${userDiaries.length}');
    print('Number of lookbooks : ${lookbookCnt}');
    print('Number of items in the wardrobe : ${itemCnt}');
    print('Number of followers: $followerCnt');
  }

  // Check if this is the user's first time
  Future<void> _checkAndShowTutorial() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasSeenTutorial = prefs.getBool('hasSeenDiaryTutorial') ?? false;

    if (!hasSeenTutorial) {
      // Wait for UI to build
      Future.delayed(Duration(milliseconds: 800), () {
        _showTutorial();
        prefs.setBool('hasSeenDiaryTutorial', true);
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
        print("Tutorial finished");
      },
      onClickTarget: (target) {
        print('Clicked on ${target.identify}');
      },
      onSkip: () {
        print("Tutorial skipped");
        return true;
      },
    );
  }

  List<TargetFocus> _createTargets() {
    List<TargetFocus> targets = [];

    // Target 1: Profile Picture
    targets.add(
      TargetFocus(
        identify: "profile-picture",
        keyTarget: _profileKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.Circle,
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
                      "Profile Picture",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "여기를 탭해서 프로필 사진을 변경하세요",
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

    // Target 2: Add Diary Button
    targets.add(
      TargetFocus(
        identify: "add-diary",
        keyTarget: _addDiaryKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 5,
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
                    Icon(Icons.edit_calendar, color: Color(0xFFCAD83B), size: 40),
                    SizedBox(height: 10),
                    Text(
                      "Add New Diary",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "여기를 탭해서 새로운 다이어리를 작성하세요!",
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

    // Target 3: Diary Tab
    targets.add(
      TargetFocus(
        identify: "diary-tab",
        keyTarget: _diaryTabKey,
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
                      "Diary View",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "모든 다이어리를 카드 그리드 형태로 볼 수 있습니다",
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

    // Target 4: Map Tab
    targets.add(
      TargetFocus(
        identify: "map-tab",
        keyTarget: _mapTabKey,
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
                    Icon(Icons.map, color: Color(0xFFCAD83B), size: 40),
                    SizedBox(height: 10),
                    Text(
                      "Map View",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "위치 기반으로 다이어리를 지도에서 확인하세요",
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

    // Target 5: More Menu
    targets.add(
      TargetFocus(
        identify: "more-menu",
        keyTarget: _moreMenuKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.Circle,
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
                      "Settings Menu",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "계정 설정, 프로필 편집 및 기타 옵션에 접근할 수 있습니다",
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

    return targets;
  }

  void _showTutorial() {
    _createTutorial();
    tutorialCoachMark?.show(context: context);
  }

  @override
  void initState() {
    super.initState();
    _getUserInfo().then((_) {
      _checkAndShowTutorial();
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      context.go('/userLogin');
    } catch (e) {
      _showSnack('로그아웃 실패: $e');
    }
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    if (user == null || uid == null) {
      _showSnack('로그인 상태가 아닙니다.');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('탈퇴'),
        content: const Text('정말 탈퇴하시겠습니까?\n(계정/데이터가 삭제될 수 있습니다)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await fs.collection('users').doc(uid).delete();
      await user.delete();

      if (!mounted) return;
      context.go('/userLogin');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showSnack('보안을 위해 다시 로그인 후 탈퇴를 진행해주세요.');
      } else {
        _showSnack('탈퇴 실패: ${e.code}');
      }
    } catch (e) {
      _showSnack('탈퇴 실패: $e');
    }
  }

  void _openMoreMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('개인정보'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/profileEdit');
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('사용 방법'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showTutorial();
                },
              ),
              ListTile(
                leading: const Icon(Icons.star_border),
                title: const Text('구독하기'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSnack('구독하기는 준비 중입니다.');
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('로그아웃'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _logout();
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_off_outlined),
                title: const Text('탈퇴'),
                textColor: Colors.red,
                iconColor: Colors.red,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _deleteAccount();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteDiary(String diaryId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      _showSnack('로그인 상태가 아닙니다');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        title: const Text(
          'Confirm',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        content: const Text(
          '정말 이 다이어리를 삭제하시겠습니까?\n삭제 후에는 되돌릴 수 없습니다.',
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
                  onPressed: () => Navigator.pop(ctx, false),
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
                  onPressed: () => Navigator.pop(ctx, true),
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

    if (confirmed != true) return;

    try {
      await fs
          .collection('users')
          .doc(uid)
          .collection('diaries')
          .doc(diaryId)
          .delete();

      final calendarQuery = await fs
          .collection('users')
          .doc(uid)
          .collection('calendar')
          .where('diaryId', isEqualTo: diaryId)
          .limit(1)
          .get();

      if (calendarQuery.docs.isNotEmpty) {
        final calendarDocId = calendarQuery.docs.first.id;
        await fs
            .collection('users')
            .doc(uid)
            .collection('calendar')
            .doc(calendarDocId)
            .update({'inDiary': false});

        print('Calendar entry updated: inDiary set to false');
      }

      _showSnack('다이어리가 삭제되었습니다');
      await _getUserInfo();

    } catch (e) {
      _showSnack('삭제 실패: $e');
      print('Error deleting diary: $e');
    }
  }

  void _diaryDialog(BuildContext context, int index) {
    if (userDiaries.isEmpty || index >= userDiaries.length) return;

    final diary = userDiaries[index];
    final diaryId = diary['diaryId'];
    final diaryImg = diary['imageUrl'];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 5),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on, size: 20),
                            SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                "${diary['locationText'] ?? '위치 없음'}",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 20),
                            SizedBox(width: 5),
                            Text("${diary['formattedDate'] ?? 'No date'}"),
                          ],
                        ),
                        SizedBox(height: 20),
                        Image.network(
                          diaryImg,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 300,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 300,
                              color: Colors.grey[300],
                              child: Icon(Icons.image_not_supported, size: 80),
                            );
                          },
                        ),
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              '${diary['comment'] ?? "No comment"}',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 3,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    iconSize: 20.0,
                    icon: Icon(Icons.edit),
                    onPressed: () {
                      Navigator.pop(context);
                      final date = diary['date'] as Timestamp?;
                      context.go('/userDiaryAdd', extra: {
                        'lookbookId': diary['lookbookId'],
                        'date': date,
                        'selectedDay': date?.toDate(),
                      });
                    },
                  ),
                  IconButton(
                      iconSize: 20.0,
                      onPressed: () async {
                        await _deleteDiary(diaryId);
                        if (mounted && Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                      icon: Icon(Icons.delete)
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  final TransformationController _transformController =
  TransformationController();

  Future<void> _pickImage() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showSnack('로그인 상태가 아닙니다');
      return;
    }

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() => isProcessingImage = true);

    try {
      final File imageFile = File(image.path);

      final String fileName = 'profile_$uid.jpg';
      final Reference storageRef = storage
          .ref('user_profile_pictures/${fileName}');

      final UploadTask uploadTask = storageRef.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      await fs.collection('users').doc(uid).update({
        'profileImageUrl': downloadUrl,
      });

      setState(() {
        selectedImage = imageFile;
        profileImageUrl = downloadUrl;
      });

      _showSnack('프로필 사진이 업데이트되었습니다');

    } catch (e) {
      print('Error uploading profile image: $e');
      _showSnack('프로필 사진 업로드 실패: $e');
    } finally {
      setState(() => isProcessingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              Container(
                width: double.infinity,
                height: 180,
                color: Colors.black,
                child: Stack(
                  children: [
                    Positioned(
                      left: 15,
                      top: 25,
                      child: GestureDetector(
                        key: _profileKey,  // ADD KEY
                        onTap: isProcessingImage ? null : _pickImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: profileImageUrl != null
                                  ? NetworkImage(profileImageUrl!)
                                  : null,
                              child: profileImageUrl == null
                                  ? Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.grey[600],
                              )
                                  : null,
                            ),
                            if (isProcessingImage)
                              Positioned.fill(
                                child: CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.black54,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black, width: 1),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 15,
                      left: 130,
                      right: 70,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${userInfo['nickname'] ?? 'UID'} \n@${userInfo['loginId'] ?? 'user ID'}",
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "$itemCnt \nitems",
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(width: 15),
                              Text(
                                "$lookbookCnt \nlookbook",
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(width: 15),
                              GestureDetector(
                                onTap: () => context.go('/followList'),
                                child: Text(
                                  "$followerCnt \nfollowers",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            key: _addDiaryKey,  // ADD KEY
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(140, 32),
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            onPressed: () => context.go('/calendarPage'),
                            child: const Text(
                              "+ diary",
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 8,
                      child: SizedBox(
                        key: _moreMenuKey,  // ADD KEY
                        width: 56,
                        height: 56,
                        child: IconButton(
                          onPressed: _openMoreMenu,
                          icon: const Icon(
                            Icons.more_horiz,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        key: _diaryTabKey,  // ADD KEY
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => context.go('/userDiaryCards'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFCAD83B),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                              side: const BorderSide(color: Colors.black),
                            ),
                          ),
                          child: const Text(
                            'diary',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        key: _mapTabKey,  // ADD KEY
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => context.go('/diaryMap'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                              side: const BorderSide(color: Colors.black),
                            ),
                          ),
                          child: const Text(
                            'map',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: userDiaries.isEmpty
                    ? Center(
                  child: Text('아직 다이어리가 없습니다'),
                )
                    : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: userDiaries.length,
                  itemBuilder: (context, index) {
                    final diary = userDiaries[index];

                    return GestureDetector(
                      onTap: () => _diaryDialog(context, index),
                      child: Card(
                        child: Column(
                          children: [
                            Expanded(
                              child: Center(
                                child: Image.network(
                                  diary['imageUrl'],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 300,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 300,
                                      color: Colors.grey[300],
                                      child: Icon(Icons.image_not_supported, size: 80),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}