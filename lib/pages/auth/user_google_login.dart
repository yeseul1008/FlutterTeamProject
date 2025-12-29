import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsign;

import '../../firebase/firestore_service.dart';

class GoogleLogin extends StatelessWidget {
  const GoogleLogin({super.key});

  Future<UserCredential?> _signInWithGoogle() async {
    final gsign.GoogleSignIn googleSignIn = gsign.GoogleSignIn(
      scopes: const ['email'],
    );

    final gsign.GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null; // 사용자가 취소

    final gsign.GoogleSignInAuthentication googleAuth =
    await googleUser.authentication;

    final OAuthCredential credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );

    final UserCredential userCred =
    await FirebaseAuth.instance.signInWithCredential(credential);

    final user = userCred.user;
    if (user == null) {
      throw FirebaseAuthException(code: 'user-null', message: 'user is null');
    }

    final fs = FirestoreService();
    final uid = user.uid;

    // ✅ 문서 기반 로그인: users/{uid} 확인
    final userDoc = await fs.getUser(uid);

    final authEmail = (user.email ?? '').trim();
    final authPhone = (user.phoneNumber ?? '').trim();
    final authNickname = (user.displayName ?? '구글유저').trim();
    final authPhotoUrl = user.photoURL;

    if (!userDoc.exists) {
      // 신규/꼬임 방지: 없으면 생성
      final safeLoginId = authEmail.isNotEmpty ? authEmail : uid;

      await fs.createUser(
        userId: uid,
        loginId: safeLoginId,
        email: authEmail,
        phone: authPhone,
        provider: 'google',
        nickname: authNickname,
        profileImageUrl: authPhotoUrl,
      );

      await fs.initFollowDoc(uid);
    } else {
      // 있으면: Auth 정보가 바뀐 경우 동기화(콘솔/구글 프로필 변경 대응)
      final data = userDoc.data() ?? {};

      final docEmail = (data['email'] ?? '').toString().trim();
      final docNickname = (data['nickname'] ?? '').toString().trim();
      final docPhone = (data['phone'] ?? '').toString().trim();
      final docProfile = (data['profileImageUrl'] ?? '').toString().trim();
      final docProvider = (data['provider'] ?? '').toString().trim();

      final patch = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (docProvider.isEmpty || docProvider != 'google') {
        patch['provider'] = 'google';
      }
      if (authEmail.isNotEmpty && authEmail != docEmail) {
        patch['email'] = authEmail;
      }
      if (authNickname.isNotEmpty && authNickname != docNickname) {
        patch['nickname'] = authNickname;
      }
      if (authPhone.isNotEmpty && authPhone != docPhone) {
        patch['phone'] = authPhone;
      }
      if ((authPhotoUrl ?? '').isNotEmpty && authPhotoUrl != docProfile) {
        patch['profileImageUrl'] = authPhotoUrl;
      }

      // patch가 updatedAt만 있으면 업데이트 스킵
      if (patch.length > 1) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update(patch);
      }

      // follows 문서 안전 초기화(merge)
      await fs.initFollowDoc(uid);
    }

    return userCred;
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0B0B0F);
    const purple = Color(0xFFA88AF7);

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: () async {
              try {
                final result = await _signInWithGoogle();
                if (result == null) return;

                if (context.mounted) {
                  // 기존 로그인과 동일한 진입 경로로 통일
                  context.go('/userDiaryCards');
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('구글 로그인 실패: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: purple,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Google로 시작하기',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
