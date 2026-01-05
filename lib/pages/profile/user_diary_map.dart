import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';

class DiaryMap extends StatefulWidget {
  const DiaryMap({super.key});

  @override
  State<DiaryMap> createState() => _DiaryMapState();
}

class _DiaryMapState extends State<DiaryMap> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  Map<String, dynamic> userInfo = {};
  int lookbookCnt = 0;
  int itemCnt = 0;
  File? selectedImage;
  bool isProcessingImage = false;
  String? profileImageUrl;
  int followerCnt = 0;

  // Follower count
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

  // Google Maps variables
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  // CHANGED: Now stores a LIST of diaries per location
  Map<String, List<Map<String, dynamic>>> _diaryData = {};
  static const LatLng _defaultLocation = LatLng(37.4563, 126.7052); // Incheon

  // Search controller
  final TextEditingController _searchController = TextEditingController();

  String formatKoreanDate(Timestamp? timestamp) {
    if (timestamp == null) return '날짜 없음';
    final dt = timestamp.toDate();
    return '${dt.year}년 ${dt.month}월 ${dt.day}일';
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

    // Get items count
    final wardrobeSnapshot = await fs
        .collection('users')
        .doc(uid)
        .collection('wardrobe')
        .get();

    // Get followers count
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

      // Group diaries by location coordinates
      Map<String, List<Map<String, dynamic>>> groupedDiaries = {};

      for (var doc in diariesSnapshot.docs) {
        final data = doc.data();
        final location = data['location'] as GeoPoint?;

        if (location != null) {
          // Create a key based on coordinates (rounded to avoid floating point issues)
          final locationKey = '${location.latitude.toStringAsFixed(6)}_${location.longitude.toStringAsFixed(6)}';

          final diaryEntry = {
            'id': doc.id,
            'locationText': data['locationText'] as String?,
            'date': data['date'] as Timestamp?,
            'lookbookId': data['lookbookId'] as String?,
            'comment': data['comment'] as String?,
            'location': location,
          };

          // Add to grouped list
          if (groupedDiaries.containsKey(locationKey)) {
            groupedDiaries[locationKey]!.add(diaryEntry);
          } else {
            groupedDiaries[locationKey] = [diaryEntry];
          }
        }
      }

      // Create markers for each unique location
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

  // Search location
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

    // Load images for all diaries at this location
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

              // List of diaries
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
                        // Date
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

                        // Image
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

                        // Comment
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

  // 이미지 확대/이동 컨트롤러
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
      maxWidth: 800, // Optimize image size
      maxHeight: 800,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() => isProcessingImage = true);

    try {
      final File imageFile = File(image.path);

      // Create a reference to Firebase Storage
      final String fileName = 'profile_$uid.jpg';
      final Reference storageRef =
      storage.ref('user_profile_pictures/${fileName}');

      // Upload the file
      final UploadTask uploadTask = storageRef.putFile(imageFile);

      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;

      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Update Firestore with the new profile image URL
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
    _loadDiaryLocations();
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
    // final topPad = MediaQuery.of(context).padding.top;

    return Container(
        color: Colors.black,
        child: SafeArea(
            bottom: false,
            child: Scaffold(
              backgroundColor: Colors.white,
              body: Column(
                children: [
                  // Custom AppBar
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
                                      "$followerCnt \nfollowers",  // UPDATED: Changed from "AI lookbook" to "followers"
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
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
                          top:  2,
                          right: 8,
                          child: SizedBox(
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

          // Google Map
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
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