import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/common/main_btn.dart';

class FindId extends StatefulWidget {
  const FindId({super.key});

  @override
  State<FindId> createState() => _FindIdState();
}

class _FindIdState extends State<FindId> {
  final _emailController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일을 입력해주세요.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호 재설정 이메일을 발송했습니다. 메일함을 확인해주세요.')),
      );

      context.go('/userLogin');
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'invalid-email' => '이메일 형식이 올바르지 않습니다.',
        'user-not-found' => '해당 이메일로 가입된 계정이 없습니다.',
        'too-many-requests' => '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.',
        _ => '이메일 발송에 실패했습니다. (${e.code})',
      };

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일 발송 중 오류가 발생했습니다.')),
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
                    width: 220,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 32),

                const Text(
                  '이메일',
                  style: TextStyle(color: textGrey, fontSize: 12),
                ),
                const SizedBox(height: 8),

                _InputField(
                  controller: _emailController,
                  hintText: '가입된 이메일을 입력하세요',
                  icon: Icons.mail_outline,
                  borderColor: border,
                  hintColor: textGrey,
                  textColor: Colors.white,
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 24),

                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _sendResetEmail,
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
                      '확인',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '기억이 나셨나요? ',
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.75),
                        fontSize: 12,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/'),
                      child: const Text(
                        '로그인으로 돌아가기 >',
                        style: TextStyle(
                          color: border,
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
  final TextInputType? keyboardType;
  final bool obscureText;

  const _InputField({
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.borderColor,
    required this.hintColor,
    required this.textColor,
    this.keyboardType,
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