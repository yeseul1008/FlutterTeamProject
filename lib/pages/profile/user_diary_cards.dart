import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';

class UserDiaryCards extends StatefulWidget {
  final int initialPage; // 0 for diary, 1 for map

  const UserDiaryCards({super.key, this.initialPage = 0});

  @override
  State<UserDiaryCards> createState() => _UserDiaryCardsState();
}

class _UserDiaryCardsState extends State<UserDiaryCards> with SingleTickerProviderStateMixin {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;
  late PageController _pageController = PageController();

  int _currentPage = 0;

  // GlobalKeys for tutorial targets
  final GlobalKey _profileKey = GlobalKey();
  final GlobalKey _addDiaryKey = GlobalKey();
  final GlobalKey _diaryTabKey = GlobalKey();
  final GlobalKey _mapTabKey = GlobalKey();
  final GlobalKey _moreMenuKey = GlobalKey();
  final GlobalKey _searchBarKey = GlobalKey();
  final GlobalKey _mapKey = GlobalKey();

  TutorialCoachMark? tutorialCoachMark;
  TabController? _tabController;

  // Shared header data
  Map<String, dynamic> userInfo = {};
  int lookbookCnt = 0;
  int itemCnt = 0;
  int followerCnt = 0;
  String? profileImageUrl;
  bool isProcessingImage = false;
  bool isLoading = true;
  bool isMapLoading = true;
  bool hasMapBeenLoaded = false;

  // Diary page data
  List<Map<String, dynamic>> userDiaries = [];

  // Map page data
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Map<String, List<Map<String, dynamic>>> _diaryData = {};
  static const LatLng _defaultLocation = LatLng(37.4563, 126.7052);
  final TextEditingController _searchController = TextEditingController();

  // Cards highlight effect
  String? _highlightedDiaryId; //
  Timer? _highlightTimer;

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

  Future<void> _loadAllData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      if (!mounted) return;
      context.go('/userLogin');
      return;
    }

    // Load user info
    final userSnapshot = await fs.collection('users').doc(uid).get();
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

    // Load diaries
    final diariesSnapshot = await fs
        .collection('users')
        .doc(uid)
        .collection('diaries')
        .orderBy('createdAt', descending: true)
        .get();

    // Load diary locations for map
    Map<String, List<Map<String, dynamic>>> groupedDiaries = {};
    for (var doc in diariesSnapshot.docs) {
      final data = doc.data();
      final location = data['location'] as GeoPoint?;

      if (location != null) {
        final locationKey =
            '${location.latitude.toStringAsFixed(6)}_${location.longitude.toStringAsFixed(6)}';

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
            snippet: count > 1
                ? '$count개의 일기'
                : formatKoreanDate(firstDiary['date']),
          ),
          onTap: () => _showDiaryDialog(locationKey),
        ),
      );
    });

    if (!mounted) return;
    setState(() {
      userInfo = userSnapshot.data() ?? {'userId': uid};
      lookbookCnt = lookbookSnapshot.docs.length;
      itemCnt = wardrobeSnapshot.docs.length;
      followerCnt = followerCount;
      profileImageUrl = userInfo['profileImageUrl'];

      userDiaries = diariesSnapshot.docs.map((doc) {
        final data = doc.data();
        data['diaryId'] = doc.id;
        data['formattedDate'] = formatKoreanDate(data['date']);
        return data;
      }).toList();

      _markers = markers;
      _diaryData = groupedDiaries;
      isLoading = false;
    });

    print('Loaded ${userDiaries.length} diaries');
    print('Loaded ${_markers.length} map markers');
  }

  Future<void> _checkAndShowTutorial() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // bool hasSeenTutorial = prefs.getBool('hasSeenDiaryTutorial') ?? false;
    bool hasSeenTutorial = false;

    if (!hasSeenTutorial) {
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
        print("Diary tutorial finished");
      },
      onClickTarget: (target) {
        print('Clicked on ${target.identify}');

        // When user clicks on map-tab target, switch to map view
        if (target.identify == "map-tab") {
          // Switch to map tab
          _pageController.animateToPage(
            1,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          _tabController!.animateTo(1);

          // Ensure map is loaded
          setState(() {
            hasMapBeenLoaded = true;
          });

          // Small delay to ensure map elements are rendered
          Future.delayed(Duration(milliseconds: 400), () {
            // Tutorial will automatically continue to next target
          });
        }
      },
      onSkip: () {
        print("Diary tutorial skipped");
        return true;
      },
    );
  }

  List<TargetFocus> _createTargets() {
    List<TargetFocus> targets = [];

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
                      "Create Diary",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "새로운 다이어리를 작성하려면 여기를 탭하세요",
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

    // Target 4: Diary Tab
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
                    Icon(Icons.grid_view, color: Color(0xFFCAD83B), size: 40),
                    SizedBox(height: 10),
                    Text(
                      "Diary Grid View",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "모든 다이어리를 그리드 형태로 볼 수 있습니다. 다이어리를 탭하여 자세히 보세요",
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

    // Target 5: Map Tab - WITH NAVIGATION
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
                      "지도에서 위치별로 다이어리를 확인할 수 있습니다. 계속하려면 탭하세요",
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

    // Target 6: Search Bar - ONLY VISIBLE ON MAP TAB
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

    // Target 7: Map View
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

    // Target 3: More Menu
    targets.add(
      TargetFocus(
        identify: "more-menu",
        keyTarget: _moreMenuKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.Circle,
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
                    Icon(Icons.more_horiz, color: Color(0xFFCAD83B), size: 40),
                    SizedBox(height: 10),
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
                      "개인정보, 구독, 로그아웃 등의 설정 메뉴에 접근할 수 있습니다",
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
    _pageController = PageController(initialPage: widget.initialPage);
    _currentPage = widget.initialPage;
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData().then((_) {
      _checkAndShowTutorial();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabController?.dispose();
    _searchController.dispose();
    _highlightTimer?.cancel();
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
      backgroundColor: Colors.white,
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
        title: const Text('Confirm', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text('정말 이 다이어리를 삭제하시겠습니까?\n삭제 후에는 되돌릴 수 없습니다.'),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCAD83B)),
                  child: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await fs.collection('users').doc(uid).collection('diaries').doc(diaryId).delete();

      final calendarQuery = await fs
          .collection('users')
          .doc(uid)
          .collection('calendar')
          .where('diaryId', isEqualTo: diaryId)
          .limit(1)
          .get();

      if (calendarQuery.docs.isNotEmpty) {
        await fs
            .collection('users')
            .doc(uid)
            .collection('calendar')
            .doc(calendarQuery.docs.first.id)
            .update({'inDiary': false});
      }

      _showSnack('다이어리가 삭제되었습니다');
      await _loadAllData();
    } catch (e) {
      _showSnack('삭제 실패: $e');
    }
  }

  void _diaryDialog(BuildContext context, int index) {
    if (userDiaries.isEmpty || index >= userDiaries.length) return;

    final diary = userDiaries[index];
    final diaryId = diary['diaryId'];
    final diaryImg = diary['imageUrl'];
    final additionalImages = diary['additionalImages'] as List<dynamic>? ?? [];

    // Create list of all images (main image + additional images)
    final List<String> allImages = [diaryImg, ...additionalImages.cast<String>()];

    int currentImageIndex = 0;
    final PageController imagePageController = PageController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return Stack(
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 20),
                            SizedBox(width: 5),
                            Expanded(
                              child: Text("${diary['locationText'] ?? '위치 없음'}"),
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

                        // Image carousel with PageView
                        SizedBox(
                          height: 300,
                          child: Stack(
                            children: [
                              PageView.builder(
                                controller: imagePageController,
                                itemCount: allImages.length,
                                onPageChanged: (index) {
                                  setDialogState(() {
                                    currentImageIndex = index;
                                  });
                                },
                                itemBuilder: (context, imgIndex) {
                                  return Image.network(
                                    allImages[imgIndex],
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
                                  );
                                },
                              ),

                              // Image counter badge (e.g., "1/5")
                              if (allImages.length > 1)
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${currentImageIndex + 1}/${allImages.length}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),

                              // Left arrow
                              // if (allImages.length > 1 && currentImageIndex > 0)
                              //   Positioned(
                              //     left: 8,
                              //     top: 0,
                              //     bottom: 0,
                              //     child: Center(
                              //       child: GestureDetector(
                              //         onTap: () {
                              //           imagePageController.previousPage(
                              //             duration: Duration(milliseconds: 300),
                              //             curve: Curves.easeInOut,
                              //           );
                              //         },
                              //         child: Container(
                              //           padding: EdgeInsets.all(8),
                              //           decoration: BoxDecoration(
                              //             color: Colors.white.withOpacity(0.8),
                              //             shape: BoxShape.circle,
                              //           ),
                              //           child: Icon(Icons.chevron_left, size: 30),
                              //         ),
                              //       ),
                              //     ),
                              //   ),
                              //
                              // // Right arrow
                              // if (allImages.length > 1 && currentImageIndex < allImages.length - 1)
                              //   Positioned(
                              //     right: 8,
                              //     top: 0,
                              //     bottom: 0,
                              //     child: Center(
                              //       child: GestureDetector(
                              //         onTap: () {
                              //           imagePageController.nextPage(
                              //             duration: Duration(milliseconds: 300),
                              //             curve: Curves.easeInOut,
                              //           );
                              //         },
                              //         child: Container(
                              //           padding: EdgeInsets.all(8),
                              //           decoration: BoxDecoration(
                              //             color: Colors.white.withOpacity(0.8),
                              //             shape: BoxShape.circle,
                              //           ),
                              //           child: Icon(Icons.chevron_right, size: 30),
                              //         ),
                              //       ),
                              //     ),
                              //   ),
                            ],
                          ),
                        ),

                        // Dot indicators
                        if (allImages.length > 1) ...[
                          SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              allImages.length,
                                  (dotIndex) => Container(
                                margin: EdgeInsets.symmetric(horizontal: 4),
                                width: currentImageIndex == dotIndex ? 8 : 6,
                                height: currentImageIndex == dotIndex ? 8 : 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: currentImageIndex == dotIndex
                                      ? Colors.black
                                      : Colors.grey[400],
                                ),
                              ),
                            ),
                          ),
                        ],

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
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  await _deleteDiary(diaryId);
                                  if (mounted && Navigator.canPop(context)) {
                                    Navigator.pop(context);
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  final date = diary['date'] as Timestamp?;
                                  context.go('/userDiaryAdd', extra: {
                                    'lookbookId': diary['lookbookId'],
                                    'date': date,
                                    'selectedDay': date?.toDate(),
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFCAD83B),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: const Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

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
      final Reference storageRef = storage.ref('user_profile_pictures/$fileName');

      final UploadTask uploadTask = storageRef.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      await fs.collection('users').doc(uid).update({
        'profileImageUrl': downloadUrl,
      });

      setState(() => profileImageUrl = downloadUrl);
      _showSnack('프로필 사진이 업데이트되었습니다');
    } catch (e) {
      print('Error uploading profile image: $e');
      _showSnack('프로필 사진 업로드 실패: $e');
    } finally {
      setState(() => isProcessingImage = false);
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      _showSnack('검색어를 입력해주세요');
      return;
    }

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final newPosition = LatLng(location.latitude, location.longitude);

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(newPosition, 14),
        );
        _showSnack('위치를 찾았습니다!');
        _searchController.clear();
      } else {
        _showSnack('위치를 찾을 수 없습니다');
      }
    } catch (e) {
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
      List<dynamic> additionalImages = [];

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

        // Fetch additional images from diary document
        final diaryDoc = await fs
            .collection('users')
            .doc(uid)
            .collection('diaries')
            .doc(diary['id'])
            .get();

        if (diaryDoc.exists) {
          additionalImages = diaryDoc.data()?['additionalImages'] ?? [];
        }
      } catch (e) {
        print('Error loading image: $e');
      }

      diariesWithImages.add({
        ...diary,
        'imageUrl': imageUrl,
        'additionalImages': additionalImages,
      });
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final hasMultipleEntries = diariesWithImages.length > 1;

        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
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
                          fontSize: 14,
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

              // Content - Different sizing based on entry count
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: hasMultipleEntries
                        ? screenHeight * 0.45
                        : screenHeight * 0.65,
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: List.generate(
                        diariesWithImages.length,
                            (index) {
                          final diary = diariesWithImages[index];
                          final imageUrl = diary['imageUrl'];
                          final additionalImages = diary['additionalImages'] as List<dynamic>? ?? [];

                          // Create list of all images
                          final List<String> allImages = [
                            if (imageUrl != null) imageUrl,
                            ...additionalImages.cast<String>()
                          ];

                          return GestureDetector(
                            onTap: () {
                              // Close the map dialog
                              Navigator.pop(context);

                              // Find the index of this diary in userDiaries
                              final diaryIndex = userDiaries.indexWhere(
                                      (d) => d['diaryId'] == diary['id']
                              );

                              if (diaryIndex != -1) {
                                // Highlight
                                setState(() {
                                  _highlightedDiaryId = diary['id'];
                                });
                                // Switch to diary tab
                                _pageController.animateToPage(
                                  0,
                                  duration: Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                                _tabController!.animateTo(0);

                                // Open the diary dialog after a short delay
                                Future.delayed(Duration(milliseconds: 400), () {
                                  _diaryDialog(context, diaryIndex);
                                });

                                // Remove highlight effect
                                _highlightTimer?.cancel();
                                _highlightTimer = Timer(Duration(seconds: 1), () {
                                  if (mounted) {
                                    setState(() {
                                      _highlightedDiaryId = null;
                                    });
                                  }
                                });
                              }
                            },
                            child: _MapDiaryEntry(
                              diary: diary,
                              allImages: allImages,
                              hasMultipleEntries: hasMultipleEntries,
                              formatKoreanDate: formatKoreanDate,
                              isLastEntry: index == diariesWithImages.length - 1,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 180,
      color: Colors.black,
      child: Stack(
        children: [
          Positioned(
            left: 15,
            top: 25,
            child: GestureDetector(
              key: _profileKey,
              onTap: isProcessingImage ? null : _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl!) : null,
                    child: profileImageUrl == null
                        ? Icon(Icons.person, size: 40, color: Colors.grey[600])
                        : null,
                  ),
                  if (isProcessingImage)
                    Positioned.fill(
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.black54,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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
                      child: Icon(Icons.camera_alt, size: 16, color: Colors.black),
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
              children: [
                Text(
                  "${userInfo['nickname'] ?? 'UID'} \n@${userInfo['loginId'] ?? 'user ID'}",
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("$itemCnt \nitems",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                    const SizedBox(width: 15),
                    Text("$lookbookCnt \nlookbook",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                    const SizedBox(width: 15),
                    GestureDetector(
                      onTap: () => context.go('/followList'),
                      child: Text("$followerCnt \nfollowers",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  key: _addDiaryKey,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(140, 32),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  onPressed: () => context.go('/calendarPage'),
                  child: const Text(
                    "+ diary",
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 2,
            right: 8,
            child: SizedBox(
              key: _moreMenuKey,
              width: 56,
              height: 56,
              child: IconButton(
                onPressed: _openMoreMenu,
                icon: const Icon(Icons.more_horiz, color: Colors.white, size: 40),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1), // Thin line across all tabs
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTab(
              key: _diaryTabKey,
              icon: Icons.menu_book_outlined,
              activeIcon: Icons.menu_book,
              label: 'diary',
              isActive: _currentPage == 0,
              onTap: () {
                _searchController.clear();
                _pageController.animateToPage(
                  0,
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                _tabController!.animateTo(0);
              },
            ),
          ),
          Expanded(
            child: _buildTab(
              key: _mapTabKey,
              icon: Icons.map_outlined,
              activeIcon: Icons.map,
              label: 'map',
              isActive: _currentPage == 1,
              onTap: () {
                _pageController.animateToPage(
                  1,
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                _tabController!.animateTo(1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required GlobalKey key,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  color: isActive ? Color(0xFFCAD83B) : Colors.black,
                  size: 35,
                ),
                SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Only show the thicker, shorter line for active tab
          if (isActive)
            Align(
              alignment: Alignment.center,
              child: FractionallySizedBox(
                widthFactor: 0.3, // 50% of tab width - adjust as needed
                child: Container(
                  height: 3, // Thicker line for active tab
                  color: Colors.black,
                ),
              ),
            )
          else
            SizedBox(height: 3), // Same height as active line to maintain alignment
        ],
      ),
    );
  }

  Widget _buildDiaryGrid() {
    if (userDiaries.isEmpty) {
      return Center(child: Text('아직 다이어리가 없습니다'));
    }

    return GridView.builder(
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
        final isHighlighted = _highlightedDiaryId == diary['diaryId']; // ✅ CHECK IF HIGHLIGHTED

        return GestureDetector(
          onTap: () => _diaryDialog(context, index),
          child: AnimatedContainer( // ✅ CHANGED FROM Container TO AnimatedContainer
            duration: Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                // ✅ HIGHLIGHT EFFECT
                color: isHighlighted ? Color(0xFFCAD83B) : Colors.grey[100]!,
                width: isHighlighted ? 4 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isHighlighted
                      ? Color(0xFFCAD83B).withOpacity(0.5) // ✅ GLOW EFFECT
                      : Colors.grey.withOpacity(0.2),
                  spreadRadius: isHighlighted ? 3 : 1,
                  blurRadius: isHighlighted ? 8 : 3,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack( // ✅ ADD STACK FOR OVERLAY
                children: [
                  Image.network(
                    diary['imageUrl'],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: Icon(Icons.image_not_supported, size: 50),
                      );
                    },
                  ),
                  // ✅ OPTIONAL: ADD SUBTLE OVERLAY WHEN HIGHLIGHTED
                  if (isHighlighted)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Color(0xFFCAD83B),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapView() {
    if (!hasMapBeenLoaded && _currentPage == 1) {
      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            hasMapBeenLoaded = true;
          });
        }
      });

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFCAD83B)),
            SizedBox(height: 16),
            Text(
              '지도를 불러오는 중...',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (!hasMapBeenLoaded) {
      return Container();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            key: _searchBarKey,
            children: [
              Expanded(
                child: GooglePlaceAutoCompleteTextField(
                  textEditingController: _searchController,
                  googleAPIKey: dotenv.env['GOOGLEMAP_API_KEY'] ?? '',
                  inputDecoration: InputDecoration(
                    hintText: '예) 강남역, 성수동, 홍대입구',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    // ✅ Clean borders - no filled background
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black, width: 1.2),
                    ),
                    // ❌ Removed filled and fillColor
                  ),
                  debounceTime: 400,
                  countries: ["kr"],
                  isLatLngRequired: true,
                  getPlaceDetailWithLatLng: (prediction) {
                    print("Selected place: ${prediction.description}");

                    if (prediction.lat != null && prediction.lng != null) {
                      final newPosition = LatLng(
                          double.parse(prediction.lat!),
                          double.parse(prediction.lng!)
                      );

                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(newPosition, 14),
                      );

                      _showSnack('위치를 찾았습니다!');
                    }
                  },
                  itemClick: (prediction) {
                    _searchController.text = prediction.description ?? "";
                    _searchController.selection = TextSelection.fromPosition(
                      TextPosition(offset: prediction.description?.length ?? 0),
                    );
                  },
                  seperatedBuilder: Divider(height: 1, color: Colors.grey[300]),
                  itemBuilder: (context, index, prediction) {
                    print('Building suggestion $index: ${prediction.description}');
                    return Container(
                      color: Colors.white,
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, size: 20, color: Colors.grey[600]),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              prediction.description ?? "",
                              style: TextStyle(fontSize: 14, color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  isCrossBtnShown: true,
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

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GoogleMap(
                key: _mapKey,
                initialCameraPosition: CameraPosition(target: _defaultLocation, zoom: 12),
                markers: _markers,
                onMapCreated: (controller) => _mapController = controller,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
              ),
            ),
          ),
        ),
        SizedBox(height: 120),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || _tabController == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 10),
              _buildTabButtons(),
              const SizedBox(height: 20),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                    _tabController!.animateTo(index);
                  },
                  children: [
                    _buildDiaryGrid(),
                    _buildMapView(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapDiaryEntry extends StatefulWidget {
  final Map<String, dynamic> diary;
  final List<String> allImages;
  final bool hasMultipleEntries;
  final String Function(Timestamp?) formatKoreanDate;
  final bool isLastEntry;

  const _MapDiaryEntry({
    required this.diary,
    required this.allImages,
    required this.hasMultipleEntries,
    required this.formatKoreanDate,
    required this.isLastEntry,
  });

  @override
  State<_MapDiaryEntry> createState() => _MapDiaryEntryState();
}

class _MapDiaryEntryState extends State<_MapDiaryEntry> {
  late PageController _imagePageController;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _imagePageController = PageController();
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: widget.isLastEntry ? 0 : 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        // color: Colors.grey[50],
      ),
      padding: EdgeInsets.all(8),
      child: Column(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16),
                  SizedBox(width: 5),
                  Text(
                    widget.formatKoreanDate(widget.diary['date']),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Spacer(),
                  // Icon(
                  //   Icons.arrow_forward_ios,
                  //   size: 14,
                  //   color: Colors.grey[600],
                  // ),
                ],
              ),
              SizedBox(height: 12),

              // Image carousel
              if (widget.allImages.isNotEmpty)
                SizedBox(
                  height: widget.hasMultipleEntries ? 180 : 250,
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _imagePageController,
                        itemCount: widget.allImages.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentImageIndex = index;
                          });
                        },
                        itemBuilder: (context, imgIndex) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              widget.allImages[imgIndex],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: widget.hasMultipleEntries ? 180 : 250,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: widget.hasMultipleEntries ? 180 : 250,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: widget.hasMultipleEntries ? 180 : 250,
                                  color: Colors.grey[300],
                                  child: Icon(Icons.image_not_supported, size: 60),
                                );
                              },
                            ),
                          );
                        },
                      ),

                      // Image counter badge
                      if (widget.allImages.length > 1)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_currentImageIndex + 1}/${widget.allImages.length}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else
                Container(
                  height: widget.hasMultipleEntries ? 180 : 250,
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

              // Dot indicators
              if (widget.allImages.length > 1) ...[
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.allImages.length,
                        (dotIndex) => Container(
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      width: _currentImageIndex == dotIndex ? 8 : 6,
                      height: _currentImageIndex == dotIndex ? 8 : 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentImageIndex == dotIndex
                            ? Colors.black
                            : Colors.grey[400],
                      ),
                    ),
                  ),
                ),
              ],

              // if (widget.diary['comment'] != null &&
              //     widget.diary['comment'].toString().isNotEmpty)
              //   Padding(
              //     padding: const EdgeInsets.only(top: 12),
              //     child: Align(
              //       alignment: Alignment.center,
              //       child: SizedBox(
              //         width: 260,
              //         child: Text(
              //           widget.diary['comment'],
              //           textAlign: TextAlign.center,
              //           style: TextStyle(fontSize: 14),
              //         ),
              //       ),
              //     ),
              //   ),
            ],
          ),
        ],
      ),
    );
  }
}