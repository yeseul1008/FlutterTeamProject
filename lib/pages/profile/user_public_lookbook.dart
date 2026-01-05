import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class PublicLookBook extends StatefulWidget {
  const PublicLookBook({super.key});

  @override
  State<PublicLookBook> createState() => _PublicLookBookState();
}

class _PublicLookBookState extends State<PublicLookBook> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  Map<String, dynamic> userInfo = {};
  List<Map<String, dynamic>> userLookbooks = [];
  List<Map<String, dynamic>> filteredLookbooks = [];  // NEW: for filtered results
  int lookbookCnt = 0;
  int itemCnt = 0;
  int followerCnt = 0;
  bool isFollowing = false;
  File? selectedImage;
  bool isProcessingImage = false;
  String? profileImageUrl;

  String? targetUserId;
  String? currentUserId;

  TextEditingController searchController = TextEditingController();
  String searchText = '';

  String formatKoreanDate(Timestamp? timestamp) {
    if (timestamp == null) return '날짜 없음';
    final dt = timestamp.toDate();
    return '${dt.year}년 ${dt.month}월 ${dt.day}일';
  }

  // NEW: Filter lookbooks based on search text
  void _filterLookbooks() {
    if (searchText.isEmpty) {
      setState(() {
        filteredLookbooks = userLookbooks;
      });
      return;
    }

    final searchLower = searchText.toLowerCase();
    setState(() {
      filteredLookbooks = userLookbooks.where((item) {
        final alias = (item['alias'] ?? '').toString().toLowerCase();
        return alias.contains(searchLower);
      }).toList();
    });

    print('Search: "$searchText" - Found ${filteredLookbooks.length} lookbooks');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    currentUserId = FirebaseAuth.instance.currentUser?.uid;

    final uri = GoRouterState.of(context).uri;
    final queryUserId = uri.queryParameters['userId'];

    if (queryUserId != targetUserId) {
      targetUserId = queryUserId ?? currentUserId;
      print('Target user changed to: $targetUserId');
      _getUserInfo();
    }
  }

  Future<void> _checkFollowingStatus() async {
    if (currentUserId == null || targetUserId == null) return;
    if (currentUserId == targetUserId) return;

    try {
      final doc = await fs
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUserId)
          .get();

      setState(() {
        isFollowing = doc.exists;
      });
    } catch (e) {
      print('Error checking follow status: $e');
    }
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

  Future<void> _toggleFollow() async {
    if (currentUserId == null || targetUserId == null) {
      _showSnack('로그인이 필요합니다');
      return;
    }

    if (currentUserId == targetUserId) {
      _showSnack('자신을 팔로우할 수 없습니다');
      return;
    }

    try {
      final currentUserDoc = await fs.collection('users').doc(currentUserId).get();
      final currentUserData = currentUserDoc.data();

      final targetUserDoc = await fs.collection('users').doc(targetUserId).get();
      final targetUserData = targetUserDoc.data();

      if (isFollowing) {
        await fs
            .collection('users')
            .doc(targetUserId)
            .collection('followers')
            .doc(currentUserId)
            .delete();

        await fs
            .collection('users')
            .doc(currentUserId)
            .collection('following')
            .doc(targetUserId)
            .delete();

        setState(() {
          isFollowing = false;
          followerCnt--;
        });

        _showSnack('팔로우 취소');
      } else {
        await fs
            .collection('users')
            .doc(targetUserId)
            .collection('followers')
            .doc(currentUserId)
            .set({
          'userId': currentUserId,
          'loginId': currentUserData?['loginId'] ?? '',
          'nickname': currentUserData?['nickname'] ?? '',
          'profileImageUrl': currentUserData?['profileImageUrl'],
          'followedAt': FieldValue.serverTimestamp(),
        });

        await fs
            .collection('users')
            .doc(currentUserId)
            .collection('following')
            .doc(targetUserId)
            .set({
          'userId': targetUserId,
          'loginId': targetUserData?['loginId'] ?? '',
          'nickname': targetUserData?['nickname'] ?? '',
          'profileImageUrl': targetUserData?['profileImageUrl'],
          'followedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          isFollowing = true;
          followerCnt++;
        });

        _showSnack('팔로우 완료');
      }
    } catch (e) {
      print('Error toggling follow: $e');
      _showSnack('오류가 발생했습니다: $e');
    }
  }

  Future<void> _getUserLookbook() async {
    final uid = targetUserId ?? currentUserId;

    if (uid == null) {
      print('ERROR: uid is null!');
      return;
    }

    print('Fetching lookbooks for userId: $uid');

    try {
      final querySnapshot = await fs
          .collection('lookbooks')
          .where('userId', isEqualTo: uid)
          .where('inLookbook', isEqualTo: true)
          .get();

      print('Query completed. Found ${querySnapshot.docs.length} lookbooks');

      final dataList = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id;
        return data;
      }).toList();

      setState(() {
        userLookbooks = dataList;
        filteredLookbooks = dataList;  // NEW: Initialize filtered list
      });

      print('Number of lookbooks loaded: ${userLookbooks.length}');
    } catch (e) {
      print('Error fetching user lookbooks: $e');
    }
  }

  Future<void> _getUserInfo() async {
    final uid = targetUserId ?? currentUserId;

    if (uid == null) {
      if (!mounted) return;
      context.go('/userLogin');
      return;
    }

    final lookbookSnapshot = await fs
        .collection('lookbooks')
        .where('userId', isEqualTo: uid)
        .where('inLookbook', isEqualTo: true)
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
      profileImageUrl = userInfo['profileImageUrl'];
    });

    await _getUserLookbook();
    await _checkFollowingStatus();

    print('Number of lookbooks: ${lookbookCnt}');
    print('Number of items in the wardrobe: ${itemCnt}');
    print('Number of followers: $followerCnt');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (userLookbooks.isEmpty) {
        _getUserInfo();
      }
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

  void _lookbookDialog(BuildContext context, int index) {
    if (filteredLookbooks.isEmpty || index >= filteredLookbooks.length) return;  // CHANGED

    final lookbook = filteredLookbooks[index];  // CHANGED
    final lookbookImg = lookbook['resultImageUrl'];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 5),
                Image.network(
                  lookbookImg,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 300,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported, size: 80),
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (lookbook['alias'] != null && lookbook['alias'].toString().isNotEmpty)
                  Text(
                    lookbook['alias'],
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
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
      final Reference storageRef = storage
          .ref('user_profile_pictures/$fileName');

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
    final isOwnProfile = targetUserId == currentUserId;

    return Container(
        color: Colors.black,  // This makes the safe area black
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
                            onTap: isOwnProfile && !isProcessingImage ? _pickImage : null,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.grey[300],
                                  backgroundImage: profileImageUrl != null
                                      ? NetworkImage(profileImageUrl!)
                                      : null,
                                  child: profileImageUrl == null
                                      ? Icon(Icons.person, size: 40, color: Colors.grey[600])
                                      : null,
                                ),
                                if (isProcessingImage)
                                  const Positioned.fill(
                                    child: CircleAvatar(
                                      radius: 40,
                                      backgroundColor: Colors.black54,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                if (isOwnProfile)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.black, width: 1),
                                      ),
                                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.black),
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
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("$itemCnt \nitems", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                                  const SizedBox(width: 15),
                                  Text("$lookbookCnt \nlookbook", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                                  const SizedBox(width: 15),
                                  GestureDetector(
                                    onTap: () => context.go('/followList${targetUserId != null ? '?userId=$targetUserId' : ''}'),
                                    child: Text("$followerCnt \nfollowers", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (!isOwnProfile)
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(140, 32),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    backgroundColor: isFollowing ? Colors.grey[300] : Colors.white,
                                  ),
                                  onPressed: _toggleFollow,
                                  child: Text(
                                    isFollowing ? "following" : "follow",
                                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isOwnProfile)
                          Positioned(
                            top: 2,
                            right: 8,
                            child: SizedBox(
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
                      onPressed: () {
                        if (targetUserId != null) {
                          context.go('/publicWardrobe?userId=$targetUserId');
                        } else {
                          context.go('/publicWardrobe');
                        }
                      },
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
                      child: const Text('wardrobe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (targetUserId != null) {
                          context.go('/publicLookBook?userId=$targetUserId');
                        } else {
                          context.go('/publicLookBook');
                        }
                      },
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
                      child: const Text('lookbook', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: searchController,
                      onChanged: (value) {
                        setState(() {
                          searchText = value.trim();
                        });
                        _filterLookbooks();  // NEW: Filter on every change
                      },
                      decoration: const InputDecoration(
                        hintText: 'search...',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: filteredLookbooks.isEmpty  // CHANGED
                ? Center(
              child: Text(
                searchText.isEmpty
                    ? '아직 룩북이 없습니다'
                    : '검색 결과가 없습니다',  // NEW
              ),
            )
                : GridView.builder(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 80,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              itemCount: filteredLookbooks.length,  // CHANGED
              itemBuilder: (context, index) {
                final lookbook = filteredLookbooks[index];  // CHANGED

                return GestureDetector(
                  onTap: () => _lookbookDialog(context, index),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        lookbook['resultImageUrl'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.image_not_supported, size: 40),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
            )
        )
    );
  }
}