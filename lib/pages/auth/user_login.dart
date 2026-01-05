import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../firebase/firestore_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../firebase/google_auth_service.dart';

class UserLogin extends StatefulWidget {
  const UserLogin({super.key});

  @override
  State<UserLogin> createState() => _UserLoginState();
}

class _UserLoginState extends State<UserLogin> {
  final _idController = TextEditingController(); // loginId 입력
  final _pwController = TextEditingController();

  bool _loading = false;
  final _fs = FirestoreService();

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final loginId = _idController.text.trim();
    final pw = _pwController.text.trim();

    if (loginId.isEmpty || pw.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이디와 비밀번호를 입력해주세요.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // 1) loginId로 users 컬렉션에서 (email, userId) 찾기
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('loginId', isEqualTo: loginId)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('존재하지 않는 아이디입니다.')),
        );
        return;
      }

      final data = snap.docs.first.data();
      final email = (data['email'] ?? '').toString().trim();

      if (email.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이 계정의 이메일 정보가 없습니다.')),
        );
        return;
      }

      // 2) FirebaseAuth는 이메일/비번으로 로그인
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pw,
      );

      final user = cred.user;
      if (user == null) {
        throw FirebaseAuthException(code: 'user-null', message: 'user is null');
      }

      final uid = user.uid;

      // 3) ✅ 로그인 성공 후: uid 기반으로 users/{uid} 문서 확인 (문서 기반 로그인)
      final userDoc = await _fs.getUser(uid);

      if (!userDoc.exists) {
        // 문서가 없으면: 데이터 기반 앱 동작이 깨짐 -> 안내 후 로그아웃
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('유저 문서(users)가 없습니다. 회원가입을 다시 진행해주세요.'),
          ),
        );
        return;
      }

      // 4) Auth 이메일과 users 문서 이메일이 다르면 동기화 (콘솔에서 이메일 변경했을 때 대비)
      final docEmail = (userDoc.data()?['email'] ?? '').toString().trim();
      final authEmail = (user.email ?? '').trim();
      if (authEmail.isNotEmpty && authEmail != docEmail) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'email': authEmail,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {
          // 동기화 실패해도 로그인 자체는 진행
        }
      }

      // 5) follows 문서가 없을 수 있으니 merge로 초기화(안전)
      await _fs.initFollowDoc(uid);

      if (!mounted) return;
      context.go('/userWardrobeList');
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'user-not-found' => '등록된 계정이 없습니다.',
        'wrong-password' => '비밀번호가 올바르지 않습니다.',
        'invalid-email' => '이메일 형식이 올바르지 않습니다.',
        'user-disabled' => '비활성화된 계정입니다.',
        'too-many-requests' => '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.',
        _ => '로그인에 실패했습니다. (${e.code})',
      };

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 중 오류가 발생했습니다.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFFFFF);
    const purple = Color(0xFFA88AF7);
    const border = Color(0xFF7B64D6);
    const textGrey = Color(0xFFB8B8C2);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.asset(
                    'assets/applogo.png',
                    width: 150,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 54),
                // const Center(
                //   child: Text(
                //     'My Outfits Daily Everyday',
                //     style: GoogleFonts.Inter(
                //       fontSize: 16,
                //       fontWeight: FontWeight.w500,
                //       color: Colors.white70,
                //       letterSpacing: 0.5,
                //     ),
                //   ),
                // ),
                const Text(
                  '아이디',
                  style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700,),
                ),
                const SizedBox(height: 8),
                _InputField(
                  controller: _idController,
                  hintText: '아이디 입력',
                  icon: Icons.account_circle_outlined,
                  borderColor: border,
                  hintColor: Colors.black54,
                  textColor: Colors.black87,
                ),
                const SizedBox(height: 16),
                const Text(
                  '비밀번호',
                  style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700,),
                ),
                const SizedBox(height: 8),
                _InputField(
                  controller: _pwController,
                  hintText: '비밀번호 입력',
                  icon: Icons.lock_outline,
                  borderColor: border,
                  hintColor: Colors.black54,
                  textColor: Colors.black87,
                  obscureText: true,
                ),
                const SizedBox(height: 18),

                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text(
                      '로그인',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Divider(
                        color: Colors.black26,
                        thickness: 1,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '또는',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ),
                    const Expanded(
                      child: Divider(
                        color: Colors.black26,
                        thickness: 1,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        final result = await GoogleAuthService.signInWithGoogle();
                        if (result == null) return;

                        if (!context.mounted) return;
                        context.go('/userWardrobeList');
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('구글 로그인에 실패했습니다.')),
                        );
                      }
                    },

                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      side: const BorderSide(
                        color: Colors.black26,
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/googleLogo.png',
                          width: 18,
                          height: 18,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Google로 시작하기',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                  ),
                ),

                const SizedBox(height: 26),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/findId'),
                    child: const Text(
                      '계정을 잃으셨나요?',
                      style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '계정이 없으신가요? ',
                      style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w700,),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/userJoin'),
                      child: const Text(
                        '회원가입',
                        style: TextStyle(
                          color: border, // 포인트 컬러 유지
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final Color borderColor;
  final Color hintColor;
  final Color textColor;
  final bool obscureText;

  const _InputField({
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.borderColor,
    required this.hintColor,
    required this.textColor,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: Colors.black,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF2F2F2), // 연한 회색 배경

          hintText: hintText,
          hintStyle: const TextStyle(
            color: Colors.black45,
            fontSize: 13,
          ),

          prefixIcon: Icon(
            icon,
            color: Colors.black54,
            size: 20,
          ),

          // 테두리 완전 제거
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
