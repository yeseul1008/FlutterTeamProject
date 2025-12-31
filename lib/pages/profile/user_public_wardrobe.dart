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
  int lookbookCnt = 0;
  int itemCnt = 0;
  File? selectedImage;
  bool isProcessingImage = false;
  String? profileImageUrl;

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

    // Get diaries from subcollection
    final diariesSnapshot = await fs
        .collection('users')
        .doc(uid)
        .collection('diaries')
        .orderBy('createdAt', descending: true)
        .get();

    // Get lookbook count
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

    final userSnapshot = await fs.collection('users').doc(uid).get();

    if (!mounted) return;
    setState(() {
      userInfo = userSnapshot.data() ?? {'userId': uid};
      lookbookCnt = lookbookSnapshot.docs.length;
      itemCnt = wardrobeSnapshot.docs.length;
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
  }

  @override
  void initState() {
    super.initState();
    _getUserInfo();
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

  // Function to delete a diary entry

  Future<void> _deleteDiary(String diaryId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      _showSnack('로그인 상태가 아닙니다');
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('다이어리 삭제'),
        content: const Text('정말 이 다이어리를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete the diary from Firestore
      await fs
          .collection('users')
          .doc(uid)
          .collection('diaries')
          .doc(diaryId)
          .delete();

      // Find and update the calendar entry with matching diaryId
      final calendarQuery = await fs
          .collection('users')
          .doc(uid)
          .collection('calendar')
          .where('diaryId', isEqualTo: diaryId)
          .limit(1)
          .get();

      // Update the calendar entry if found
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

      // Refresh the diaries list
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
    // const imageUrl = 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=600';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        child: Stack(
          children: [
            SingleChildScrollView(  // ADD THIS to make dialog scrollable
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 5),
                        // Location - UPDATED TO HANDLE LONG TEXT
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,  // Align to top
                          children: [
                            Icon(Icons.location_on, size: 20),
                            SizedBox(width: 5),
                            Expanded(  // ADD THIS to allow text wrapping
                              child: Text(
                                "${diary['locationText'] ?? '위치 없음'}",
                                maxLines: 2,  // Limit to 2 lines
                                overflow: TextOverflow.ellipsis,  // Show ... if too long
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        // Date
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 20),
                            SizedBox(width: 5),
                            Text("${diary['formattedDate'] ?? 'No date'}"),
                          ],
                        ),
                        SizedBox(height: 20),

                        // Image
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
                        // Comment
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              '${diary['comment'] ?? "No comment"}',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        SizedBox(height: 20 ),
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
                        await _deleteDiary(
                            diaryId); // wait for the function to complete
                        // await Future.delayed(Duration(milliseconds: 300));
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

  // Function to select a profile picture

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
      maxWidth: 800,  // Optimize image size
      maxHeight: 800,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() => isProcessingImage = true);

    try {
      final File imageFile = File(image.path);

      // Create a reference to Firebase Storage
      final String fileName = 'profile_$uid.jpg';
      final Reference storageRef = storage
          .ref('user_profile_pictures/${fileName}');

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
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
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
                  top: 40,
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
                  top: 25,
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
                          const Text(
                            "0 \nAI lookbook",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(140, 32),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        onPressed: () => context.go('/'),
                        child: const Text(
                          "follow",
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
                  top: topPad + 2,
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
                      onPressed: () => context.go('/publicWardrobe'),
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
                        'wardrobe',
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
                      onPressed: () => context.go('/publicLookBook'),
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
                        'lookbook',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
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
    );
  }
}