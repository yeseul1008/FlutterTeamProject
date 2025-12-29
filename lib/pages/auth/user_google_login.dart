import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

    final user = userCred.user!;
    final fs = FirestoreService();

    final email = user.email ?? '';
    final safeLoginId = email.isNotEmpty ? email : user.uid;

    // users 문서 없으면 생성 (신규/중간실패 꼬임 방지)
    final userDoc = await fs.getUser(user.uid);
    if (!userDoc.exists) {
      await fs.createUser(
        userId: user.uid,
        loginId: safeLoginId,
        email: email,
        phone: user.phoneNumber ?? '',
        provider: 'google',
        nickname: user.displayName ?? '구글유저',
        profileImageUrl: user.photoURL,
      );

      await fs.initFollowDoc(user.uid);
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

                context.go('/'); // 홈 라우트로 변경 가능
              } catch (e) {
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
