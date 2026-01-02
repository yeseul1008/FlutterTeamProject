import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class PublicWardrobe extends StatefulWidget {
  const PublicWardrobe({super.key});

  @override
  State<PublicWardrobe> createState() => _UserDiaryCardsState();
}

class _UserDiaryCardsState extends State<PublicWardrobe> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  Map<String, dynamic> userInfo = {};
  List<Map<String, dynamic>> userDiaries = [];
  List<Map<String, dynamic>> userWardrobe = [];
  int lookbookCnt = 0;
  int itemCnt = 0;
  int followerCnt = 0;
  bool isFollowing = false;
  File? selectedImage;
  bool isProcessingImage = false;
  String? profileImageUrl;

  String? targetUserId;
  String? currentUserId;

  String formatKoreanDate(Timestamp? timestamp) {
    if (timestamp == null) return '날짜 없음';
    final dt = timestamp.toDate();
    return '${dt.year}년 ${dt.month}월 ${dt.day}일';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    currentUserId = FirebaseAuth.instance.currentUser?.uid;

    final uri = GoRouterState.of(context).uri;
    final queryUserId = uri.queryParameters['userId'];

    if (queryUserId != targetUserId) {
      targetUserId = queryUserId ?? currentUserId;
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

  Future<void> _getUserInfo() async {
    final uid = targetUserId ?? currentUserId;

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
        .orderBy('createdAt', descending: true)
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
      userWardrobe = wardrobeSnapshot.docs.map((doc) {
        final data = doc.data();
        return data;
      }).toList();
    });

    await _checkFollowingStatus();

    print('Number of diary entries: ${userDiaries.length}');
    print('Number of lookbooks : ${lookbookCnt}');
    print('Number of items in the wardrobe : ${itemCnt}');
    print('Number of followers: $followerCnt');
  }

  @override
  void initState() {
    super.initState();
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

  void _wardrobeDialog(BuildContext context, int index) {
    if (userWardrobe.isEmpty || index >= userWardrobe.length) return;

    final wardrobe = userWardrobe[index];
    final wardrobeImg = wardrobe['imageUrl'];

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
                  wardrobeImg,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.checkroom),
                    const SizedBox(width: 10),
                    Text(
                      '${wardrobe['productName'] ?? 'Unknown'}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_bag),
                    const SizedBox(width: 10),
                    Text('${wardrobe['shop'] ?? 'Unknown'}'),
                  ],
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
      final Reference storageRef = storage.ref('user_profile_pictures/$fileName');

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
    final topPad = MediaQuery.of(context).padding.top;
    final isOwnProfile = targetUserId == currentUserId;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(  // CHANGED: Back to Column
        children: [
          // Fixed Header
          Container(
            width: double.infinity,
            height: 180,
            color: Colors.black,
            child: Stack(
              children: [
                Positioned(
                  left: 15,
                  top: 40,
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
                  top: 25,
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
                    top: topPad + 2,
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

          // Fixed Navigation buttons
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
                        backgroundColor: const Color(0xFFCAD83B),
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
                        backgroundColor: Colors.white,
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

          // Scrollable Grid ONLY
          Expanded(
            child: userWardrobe.isEmpty
                ? const Center(child: Text('아직 옷장이 비어있습니다'))
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
              itemCount: userWardrobe.length,
              itemBuilder: (context, index) {
                final wardrobe = userWardrobe[index];
                return GestureDetector(
                  onTap: () => _wardrobeDialog(context, index),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey[300]!,  // Border color
                        width: 1,                   // Border width
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        wardrobe['imageUrl'],
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
    );
  }
}