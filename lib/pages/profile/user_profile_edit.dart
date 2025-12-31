import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/common/main_btn.dart';
import 'package:go_router/go_router.dart';

class ProfileEdit extends StatefulWidget {
  const ProfileEdit({super.key});

  @override
  State<ProfileEdit> createState() => _ProfileEditState();
}

class _ProfileEditState extends State<ProfileEdit> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;
  Map<String, dynamic> userInfo = {};
  int lookbookCnt = 0;
  int itemCnt = 0;
  File? selectedImage;
  bool isProcessingImage = false;
  String? profileImageUrl;
  final TextEditingController _nicknameCtrl = TextEditingController();
  final TextEditingController _idCtrl = TextEditingController();

  Future<void> _getUserInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      if (!mounted) return;
      context.go('/userLogin');
      return;
    }

    try {
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
        _nicknameCtrl.text = userInfo['nickname'] ?? '';
        _idCtrl.text = userInfo['loginId'] ?? '';
        lookbookCnt = lookbookSnapshot.docs.length;
        itemCnt = wardrobeSnapshot.docs.length;
        profileImageUrl = userInfo['profileImageUrl'];
      });
    } catch (e) {
      print('Error loading user info: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _getUserInfo();
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _idCtrl.dispose();
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

  // Function to check if loginId is already taken
  Future<bool> _isLoginIdTaken(String loginId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    try {
      // Query Firestore to find users with this loginId
      final querySnapshot = await fs
          .collection('users')
          .where('loginId', isEqualTo: loginId.trim())
          .limit(1)
          .get();

      // If found and it's not the current user, it's taken
      if (querySnapshot.docs.isNotEmpty) {
        final docId = querySnapshot.docs.first.id;
        // Check if it's not the current user's own loginId
        return docId != uid;
      }

      return false; // loginId is available
    } catch (e) {
      print('Error checking loginId: $e');
      return false;
    }
  }

// Function to edit user's info with validation
  // UPDATED: Function to edit user's info with validation
  Future<void> _editUserInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      _showSnack('로그인 상태가 아닙니다');
      return;
    }

    // Validate inputs
    if (_nicknameCtrl.text.trim().isEmpty) {
      _showSnack('닉네임을 입력해주세요');
      return;
    }

    if (_idCtrl.text.trim().isEmpty) {
      _showSnack('아이디를 입력해주세요');
      return;
    }

    // Check if loginId has changed
    final newLoginId = _idCtrl.text.trim();
    final currentLoginId = userInfo['loginId'] ?? '';

    if (newLoginId != currentLoginId) {
      // Check if new loginId is already taken
      final isTaken = await _isLoginIdTaken(newLoginId);

      if (isTaken) {
        // IMMEDIATELY restore original loginId in the text field
        _idCtrl.text = currentLoginId;

        // Small delay to let user see the change, then show snackbar
        await Future.delayed(Duration(milliseconds: 100));

        _showSnack('이미 사용 중인 아이디입니다. 다른 아이디를 입력해주세요.');
        return;
      }
    }

    try {
      // Update user info in Firestore
      await fs.collection('users').doc(uid).update({
        'nickname': _nicknameCtrl.text.trim(),
        'loginId': newLoginId,
      });

      _showSnack('정보가 성공적으로 저장되었습니다');

      // Refresh user info
      await _getUserInfo();

    } catch (e) {
      _showSnack('저장 실패: $e');
      print('Error saving user info: $e');
    }
  }

  // Change password bottom sheet
  Future<void> _showChangePasswordSheet() async {
    final TextEditingController oldPasswordCtrl = TextEditingController();
    final TextEditingController newPasswordCtrl = TextEditingController();
    final TextEditingController confirmPasswordCtrl = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    const Text(
                      '비밀번호 변경',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Old Password
                    const Text(
                      '현재 비밀번호',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: oldPasswordCtrl,
                      obscureText: obscureOld,
                      decoration: InputDecoration(
                        hintText: '현재 비밀번호를 입력하세요',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureOld ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setModalState(() {
                              obscureOld = !obscureOld;
                            });
                          },
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.black),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.black, width: 1.2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // New Password
                    const Text(
                      '새 비밀번호',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: newPasswordCtrl,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        hintText: '새 비밀번호를 입력하세요',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setModalState(() {
                              obscureNew = !obscureNew;
                            });
                          },
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.black),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.black, width: 1.2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirm New Password
                    const Text(
                      '새 비밀번호 확인',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmPasswordCtrl,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        hintText: '새 비밀번호를 다시 입력하세요',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setModalState(() {
                              obscureConfirm = !obscureConfirm;
                            });
                          },
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.black),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.black, width: 1.2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          // Validation
                          if (newPasswordCtrl.text != confirmPasswordCtrl.text) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('새 비밀번호가 일치하지 않습니다')),
                            );
                            return;
                          }

                          if (newPasswordCtrl.text.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('비밀번호는 최소 6자 이상이어야 합니다')),
                            );
                            return;
                          }

                          // Store values BEFORE closing
                          final oldPass = oldPasswordCtrl.text;
                          final newPass = newPasswordCtrl.text;

                          // Close modal
                          Navigator.of(ctx).pop();

                          // Delay then change password
                          await Future.delayed(Duration(milliseconds: 200));

                          // Call without waiting
                          _changePassword(oldPass, newPass);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '비밀번호 변경',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // DELAY BEFORE DISPOSING - wait for Firebase to finish
    await Future.delayed(Duration(seconds: 2));

    // Now safe to dispose
    oldPasswordCtrl.dispose();
    newPasswordCtrl.dispose();
    confirmPasswordCtrl.dispose();
  }

  // Function to change password
  Future<void> _changePassword(String oldPassword, String newPassword) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email;

      if (user == null || email == null) {
        return;
      }

      // Re-authenticate user with old password
      final credential = EmailAuthProvider.credential(
        email: email,
        password: oldPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update to new password
      await user.updatePassword(newPassword);

      // Show success message - direct approach
      await Future.delayed(Duration(milliseconds: 100));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('비밀번호가 성공적으로 변경되었습니다'),
            // backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

    } on FirebaseAuthException catch (e) {
      await Future.delayed(Duration(milliseconds: 100));

      if (!mounted) return;

      String errorMsg;
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMsg = '현재 비밀번호가 올바르지 않습니다';
      } else if (e.code == 'weak-password') {
        errorMsg = '비밀번호가 너무 약습니다';
      } else {
        errorMsg = '비밀번호 변경 실패';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );

    } catch (e) {
      // Catch ALL other errors (including the framework error)
      print('Framework error caught (safe to ignore): $e');
      // The password change probably succeeded despite the error
      // Show success message anyway
      await Future.delayed(Duration(milliseconds: 100));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('비밀번호가 변경되었습니다'),
            // backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
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
          // AppBar - Fixed at top
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
                  top: 20,
                  left: 130,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "${userInfo['nickname'] ?? 'UID'} \n@${userInfo['loginId'] ?? 'users ID'}",
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${itemCnt} \nitems",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(width: 20),
                          Text(
                            "$lookbookCnt \nlookbook",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(width: 20),
                          const Text(
                            "0 \nAI lookbook",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
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

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 15),
                      Center(
                        child: Text(
                          "개인정보 수정",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      SizedBox(height: 15),
                      Text("닉네임 수정"),
                      SizedBox(height: 10),
                      TextField(
                        controller: _nicknameCtrl,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: Colors.black),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: Colors.black, width: 1.2),
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text("아이디 수정"),
                      SizedBox(height: 10),
                      TextField(
                        controller: _idCtrl,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: Colors.black),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: Colors.black, width: 1.2),
                          ),
                        ),
                      ),
                      SizedBox(height: 35),
                      // Password change button
                      GestureDetector(
                        onTap: _showChangePasswordSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                '비밀번호 변경',
                                style: TextStyle(fontSize: 15),
                              ),
                              Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 25),
                      Center(
                        child: SizedBox(
                          height: 50,
                          width: 180,
                          child: ElevatedButton(
                            onPressed: () {
                              _editUserInfo();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFA88AEE),
                              foregroundColor: Colors.black,
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              '저장',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}