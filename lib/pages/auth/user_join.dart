import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../firebase/firestore_service.dart';

class UserJoin extends StatefulWidget {
  const UserJoin({super.key});

  @override
  State<UserJoin> createState() => _UserJoinState();
}

class _UserJoinState extends State<UserJoin> {
  final _email = TextEditingController();
  final _loginId = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  final _phone = TextEditingController();
  final _nickname = TextEditingController();

  bool _loading = false;
  final _fs = FirestoreService();

  @override
  void dispose() {
    _email.dispose();
    _loginId.dispose();
    _pw.dispose();
    _pw2.dispose();
    _phone.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final email = _email.text.trim();
    final loginId = _loginId.text.trim();
    final pw = _pw.text.trim();
    final pw2 = _pw2.text.trim();
    final phone = _phone.text.trim();
    final nickname = _nickname.text.trim();

    if (email.isEmpty ||
        loginId.isEmpty ||
        pw.isEmpty ||
        pw2.isEmpty ||
        phone.isEmpty ||
        nickname.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 항목을 입력해주세요.')),
      );
      return;
    }

    if (pw != pw2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pw,
      );

      final user = cred.user;
      if (user == null) {
        throw FirebaseAuthException(code: 'user-null', message: 'user is null');
      }

      final uid = user.uid;

      // ✅ users/{uid} 문서 생성 (firebase.txt 최신 구조: loginId 포함)
      await _fs.createUser(
        userId: uid,
        loginId: loginId,
        email: email,
        phone: phone,
        provider: 'email',
        nickname: nickname,
        profileImageUrl: null,
      );

      // follows 문서 초기화
      await _fs.initFollowDoc(uid);

      if (!mounted) return;
      context.go('/userLogin');
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'email-already-in-use' => '이미 사용 중인 이메일입니다.',
        'invalid-email' => '이메일 형식이 올바르지 않습니다.',
        'weak-password' => '비밀번호가 너무 약합니다.',
        'operation-not-allowed' => '이메일/비밀번호 로그인이 비활성화되어 있습니다.',
        _ => '회원가입에 실패했습니다. (${e.code})',
      };

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입 중 오류가 발생했습니다.')),
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
                const SizedBox(height: 28),
                Center(
                  child: Image.asset(
                    'assets/applogo.png',
                    width: 220,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 28),

                const Text('이메일', style: TextStyle(color: Colors.black, fontSize: 12)),
                const SizedBox(height: 8),
                _InputField(
                  controller: _email,
                  hintText: '이메일 입력',
                  icon: Icons.mail_outline,
                  borderColor: border,
                  hintColor: textGrey,
                  textColor: Colors.white,
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 16),

                const Text('전화번호', style: TextStyle(color: Colors.black, fontSize: 12)),
                const SizedBox(height: 8),
                _InputField(
                  controller: _phone,
                  hintText: '전화번호 입력',
                  icon: Icons.call_outlined,
                  borderColor: border,
                  hintColor: textGrey,
                  textColor: Colors.white,
                  keyboardType: TextInputType.phone,
                ),

                const SizedBox(height: 16),

                const Text('닉네임', style: TextStyle(color: Colors.black, fontSize: 12)),
                const SizedBox(height: 8),
                _InputField(
                  controller: _nickname,
                  hintText: '닉네임 입력',
                  icon: Icons.person_outline,
                  borderColor: border,
                  hintColor: textGrey,
                  textColor: Colors.white,
                ),

                const SizedBox(height: 16),

                const Text('아이디', style: TextStyle(color: Colors.black, fontSize: 12)),
                const SizedBox(height: 8),
                _InputField(
                  controller: _loginId,
                  hintText: '아이디 입력',
                  icon: Icons.account_circle_outlined,
                  borderColor: border,
                  hintColor: textGrey,
                  textColor: Colors.white,
                ),

                const SizedBox(height: 16),

                const Text('비밀번호', style: TextStyle(color: Colors.black, fontSize: 12)),
                const SizedBox(height: 8),
                _InputField(
                  controller: _pw,
                  hintText: '비밀번호 입력',
                  icon: Icons.lock_outline,
                  borderColor: border,
                  hintColor: textGrey,
                  textColor: Colors.white,
                  obscureText: true,
                ),

                const SizedBox(height: 16),

                const Text('비밀번호 재입력',
                    style: TextStyle(color: Colors.black, fontSize: 12)),
                const SizedBox(height: 8),
                _InputField(
                  controller: _pw2,
                  hintText: '비밀번호 재입력',
                  icon: Icons.lock_outline,
                  borderColor: border,
                  hintColor: textGrey,
                  textColor: Colors.white,
                  obscureText: true,
                ),

                const SizedBox(height: 24),

                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _signup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text(
                      '회원가입 완료',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '이미 계정이 있으신가요? ',
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/userLogin'),
                      child: const Text(
                        '로그인',
                        style: TextStyle(
                          color: border,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 100),
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
  final TextInputType? keyboardType;

  const _InputField({
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.borderColor,
    required this.hintColor,
    required this.textColor,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: Colors.black,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Colors.white,

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

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(
              color: Colors.black,
              width: 1.2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(
              color: Colors.black,
              width: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}
