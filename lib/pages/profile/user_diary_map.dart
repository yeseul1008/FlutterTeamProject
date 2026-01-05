import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiaryMap extends StatefulWidget {
  const DiaryMap({super.key});

  @override
  State<DiaryMap> createState() => _DiaryMapState();
}

class _DiaryMapState extends State<DiaryMap> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  // GlobalKeys for tutorial targets
  final GlobalKey _profileKey = GlobalKey();
  final GlobalKey _addDiaryKey = GlobalKey();
  final GlobalKey _diaryTabKey = GlobalKey();
  final GlobalKey _mapTabKey = GlobalKey();
  final GlobalKey _searchBarKey = GlobalKey();
  final GlobalKey _mapKey = GlobalKey();
  final GlobalKey _moreMenuKey = GlobalKey();

  TutorialCoachMark? tutorialCoachMark;

  Map<String, dynamic> userInfo = {};
  int lookbookCnt = 0;
  int itemCnt = 0;
  File? selectedImage;
  bool isProcessingImage = false;
  String? profileImageUrl;
  int followerCnt = 0;

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Map<String, List<Map<String, dynamic>>> _diaryData = {};
  static const LatLng _defaultLocation = LatLng(37.4563, 126.7052);

  final TextEditingController _searchController = TextEditingController();

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

    final lookbookSnapshot = await fs
        .collection('lookbooks')
        .where('userId', isEqualTo: uid)
        .get();

    final wardrobeSnapshot = await fs
        .collection('users')
        .doc(uid)
        .collection('wardrobe')
        .get();

    final followerCount = await _getFollowerCount(uid);
    final userSnapshot = await fs.collection('users').doc(uid).get();

    if (!mounted) return;
    setState(() {
      userInfo = userSnapshot.data() ?? {'userId': uid};
      itemCnt = wardrobeSnapshot.docs.length;
      lookbookCnt = lookbookSnapshot.docs.length;
      profileImageUrl = userInfo['profileImageUrl'];
      followerCnt = followerCount;
    });
  }

  Future<void> _loadDiaryLocations() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final diariesSnapshot = await fs
          .collection('users')
          .doc(uid)
          .collection('diaries')
          .get();

      Map<String, List<Map<String, dynamic>>> groupedDiaries = {};

      for (var doc in diariesSnapshot.docs) {
        final data = doc.data();
        final location = data['location'] as GeoPoint?;

        if (location != null) {
          final locationKey = '${location.latitude.toStringAsFixed(6)}_${location.longitude.toStringAsFixed(6)}';

          final diaryEntry = {
            'id': doc.id,
            'locationText': data['locationText'] as String?,
            'date': data['date'] as Timestamp?,
            'lookbookId': data['lookbookId'] as String?,
            'comment': data['comment'] as String?,
            'location': location,
          };

          if (groupedDiaries.containsKey(locationKey)) {
            groupedDiaries[locationKey]!.add(diaryEntry);
          } else {
            groupedDiaries[locationKey] = [diaryEntry];
          }
        }
      }

      Set<Marker> markers = {};

      groupedDiaries.forEach((locationKey, diaries) {
        final firstDiary = diaries.first;
        final location = firstDiary['location'] as GeoPoint;
        final count = diaries.length;

        markers.add(
          Marker(
            markerId: MarkerId(locationKey),
            position: LatLng(location.latitude, location.longitude),
            infoWindow: InfoWindow(
              title: firstDiary['locationText'] ?? 'Unknown location',
              snippet: count > 1 ? '$count개의 일기' : formatKoreanDate(firstDiary['date']),
            ),
            onTap: () => _showDiaryDialog(locationKey),
          ),
        );
      });

      if (!mounted) return;
      setState(() {
        _markers = markers;
        _diaryData = groupedDiaries;
      });

      print('Loaded ${_markers.length} unique locations with ${diariesSnapshot.docs.length} total diaries');
    } catch (e) {
      print('Error loading diary locations: $e');
    }
  }

  // Check if this is the user's first time on map page
  Future<void> _checkAndShowTutorial() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasSeenMapTutorial = prefs.getBool('hasSeenMapTutorial') ?? false;

    if (!hasSeenMapTutorial) {
      Future.delayed(Duration(milliseconds: 1000), () {
        _showTutorial();
        prefs.setBool('hasSeenMapTutorial', true);
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
        print("Map tutorial finished");
      },
      onClickTarget: (target) {
        print('Clicked on ${target.identify}');
      },
      onSkip: () {
        print("Map tutorial skipped");
        return true;
      },
    );
  }

  List<TargetFocus> _createTargets() {
    List<TargetFocus> targets = [];

    // Target 1: Search Bar
    targets.add(
      TargetFocus(
        identify: "search-bar",
        keyTarget: _searchBarKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
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
                    Icon(Icons.search, color: Color(0xFFCAD83B), size: 40),
                    SizedBox(height: 10),
                    Text(
                      "Search Locations",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "'강남역', '성수동', '홍대입구'와 같은 특정 장소를 검색해서 지도를 탐색하세요",
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

    // Target 2: Map View
    targets.add(
      TargetFocus(
        identify: "map-view",
        keyTarget: _mapKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 8,
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
                    Icon(Icons.location_on, color: Color(0xFFCAD83B), size: 40),
                    SizedBox(height: 10),
                    Text(
                      "Diary Locations",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "지도에서 모든 다이어리를 확인하세요. 마커를 탭하면 다이어리 세부 정보와 이미지를 볼 수 있습니다",
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
                      "Switch to Grid View",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "지도 대신 카드 그리드 형태로 다이어리를 보려면 여기를 탭하세요",
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

    // Target 4: Add Diary Button
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
                      "Create New Diary",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "위치와 함께 새 다이어리를 추가하세요. 지도에 표시됩니다!",
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

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      _showSnack('검색어를 입력해주세요');
      return;
    }

    try {
      print('Searching for: $query');
      List<Location> locations = await locationFromAddress(query);

      print('Found ${locations.length} locations');

      if (locations.isNotEmpty) {
        final location = locations.first;
        final newPosition = LatLng(location.latitude, location.longitude);

        print('Moving to: ${location.latitude}, ${location.longitude}');

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(newPosition, 14),
        );

        _showSnack('위치를 찾았습니다!');
      } else {
        _showSnack('위치를 찾을 수 없습니다');
      }
    } catch (e) {
      print('=== SEARCH ERROR ===');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      print('==================');
      _showSnack('위치 검색 실패: $e');
    }
  }

  Future<void> _showDiaryDialog(String locationKey) async {
    final diaries = _diaryData[locationKey];
    if (diaries == null || diaries.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    List<Map<String, dynamic>> diariesWithImages = [];

    for (var diary in diaries) {
      String? imageUrl;
      try {
        final date = diary['date'] as Timestamp?;
        if (date != null) {
          final dt = date.toDate();
          final startOfDay = DateTime(dt.year, dt.month, dt.day, 0, 0, 0);
          final endOfDay = DateTime(dt.year, dt.month, dt.day, 23, 59, 59);

          final calendarQuery = await fs
              .collection('users')
              .doc(uid)
              .collection('calendar')
              .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
              .limit(1)
              .get();

          if (calendarQuery.docs.isNotEmpty) {
            imageUrl = calendarQuery.docs.first.data()['imageURL'];
          }
        }
      } catch (e) {
        print('Error loading image: $e');
      }

      diariesWithImages.add({
        ...diary,
        'imageUrl': imageUrl,
      });
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        child: Container(
          constraints: BoxConstraints(maxHeight: 600, maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "${diaries.first['locationText'] ?? '위치 없음'}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (diaries.length > 1)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color(0xFFCAD83B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${diaries.length}개',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.all(16),
                  itemCount: diariesWithImages.length,
                  separatorBuilder: (context, index) => Divider(height: 32),
                  itemBuilder: (context, index) {
                    final diary = diariesWithImages[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16),
                            SizedBox(width: 5),
                            Text(
                              formatKoreanDate(diary['date']),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        if (diary['imageUrl'] != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              diary['imageUrl'],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 250,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 250,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 250,
                                  color: Colors.grey[300],
                                  child: Icon(Icons.image_not_supported, size: 60),
                                );
                              },
                            ),
                          )
                        else
                          Container(
                            height: 250,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.image,
                                size: 60,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        if (diary['comment'] != null &&
                            diary['comment'].toString().isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              diary['comment'],
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                      ],
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
      final Reference storageRef =
      storage.ref('user_profile_pictures/${fileName}');

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
  void initState() {
    super.initState();
    _getUserInfo();
    _loadDiaryLocations().then((_) {
      _checkAndShowTutorial();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            child: const Text('취소'),
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

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  key: _searchBarKey,  // ADD KEY
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: (_) => _searchLocation(_searchController.text),
                        decoration: InputDecoration(
                          hintText: '예) 강남역, 성수동, 홍대입구',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                            const BorderSide(color: Colors.black, width: 1.2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => _searchLocation(_searchController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('검색'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    key: _mapKey,  // ADD KEY
                    height: 300,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _defaultLocation,
                          zoom: 12,
                        ),
                        markers: _markers,
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 130),
            ],
          ),
        ),
      ),
    );
  }
}