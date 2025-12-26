import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common/main_btn.dart';
import '../../widgets/common/app_logo.dart';

class UserJoin extends StatefulWidget {
  const UserJoin({super.key});

  @override
  State<UserJoin> createState() => _UserJoinState();
}

class _UserJoinState extends State<UserJoin> {
  final _emailController = TextEditingController();
  final _idController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pwController = TextEditingController();
  final _pw2Controller = TextEditingController();

  bool _agree = false;

  @override
  void dispose() {
    _emailController.dispose();
    _idController.dispose();
    _phoneController.dispose();
    _pwController.dispose();
    _pw2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0B0B0F);
    const purple = Color(0xFFA88AF7);
    const borderPurple = Color(0xFF7B64D6);
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

                // 로고 (위젯 분리된 버전)
                const Center(child: AppLogo()),
                const SizedBox(height: 10),

                const Center(
                  child: Text(
                    'What you where?',
                    style: TextStyle(
                      color: textGrey,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 26),

                const Text('이메일', style: TextStyle(color: textGrey, fontSize: 12)),
                const SizedBox(height: 8),
                _InputField(
                  controller: _emailController,
                  hintText: '이메일 입력',
                  icon: Icons.mail_outline,
                  borderColor: borderPurple,
                  hintColor: textGrey,
                  textColor: Colors.white,
                ),
                const SizedBox(height: 16),

                const Text('아이디', style: TextStyle(color: textGrey, fontSize: 12)),
                const SizedBox(height: 8),

                // 아이디 + 중복확인 버튼 (로직 생략)
                Row(
                  children: [
                    Expanded(
                      child: _InputField(
                        controller: _idController,
                        hintText: '아이디 입력',
                        icon: Icons.person_outline,
                        borderColor: borderPurple,
                        hintColor: textGrey,
                        textColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    MainButton(
                      text: '중복확인',
                      height: 44,
                      width: 84,
                      radius: 12,
                      fontSize: 12,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      backgroundColor: purple,
                      borderColor: purple,
                      textColor: Colors.white,
                      onTap: () {
                        // TODO: 중복확인 로직 (생략)
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                const Text('전화번호', style: TextStyle(color: textGrey, fontSize: 12)),
                const SizedBox(height: 8),
                _InputField(
                  controller: _phoneController,
                  hintText: '전화번호 입력',
                  icon: Icons.phone_outlined,
                  borderColor: borderPurple,
                  hintColor: textGrey,
                  textColor: Colors.white,
                ),
                const SizedBox(height: 16),

                const Text('비밀번호', style: TextStyle(color: textGrey, fontSize: 12)),
                const SizedBox(height: 8),
                _InputField(
                  controller: _pwController,
                  hintText: '비밀번호 입력',
                  icon: Icons.lock_outline,
                  borderColor: borderPurple,
                  hintColor: textGrey,
                  textColor: Colors.white,
                  obscureText: true,
                ),
                const SizedBox(height: 16),

                const Text('비밀번호 재입력', style: TextStyle(color: textGrey, fontSize: 12)),
                const SizedBox(height: 8),
                _InputField(
                  controller: _pw2Controller,
                  hintText: '비밀번호 재입력',
                  icon: Icons.lock_outline,
                  borderColor: borderPurple,
                  hintColor: textGrey,
                  textColor: Colors.white,
                  obscureText: true,
                ),

                const SizedBox(height: 18),

                // 동의 체크
                Row(
                  children: [
                    Checkbox(
                      value: _agree,
                      onChanged: (v) => setState(() => _agree = v ?? false),
                      activeColor: purple,
                      checkColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.6)),
                    ),
                    Expanded(
                      child: Text(
                        '이용약관 및 개인정보 수집에 동의합니다.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // 회원가입 버튼 (로직 비워둠)
                MainButton(
                  text: '회원가입',
                  height: 46,
                  radius: 10,
                  backgroundColor: purple,
                  borderColor: purple,
                  textColor: Colors.white,
                  onTap: () {
                    // TODO: 회원가입 로직 (생략)
                  },
                ),

                const SizedBox(height: 14),

                // 이미 계정? 로그인 (요청대로 /UserLogin 이동)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '이미 계정이 있으신가요? ',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 12,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/userLogin'),
                      child: const Text(
                        '로그인',
                        style: TextStyle(
                          color: borderPurple,
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

class _FieldIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _FieldIcon({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: color.withOpacity(0.9), size: 20);
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
      height: 44,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: TextStyle(color: textColor, fontSize: 14),
        cursorColor: borderColor,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Colors.transparent,
          hintText: hintText,
          hintStyle: TextStyle(color: hintColor.withOpacity(0.7), fontSize: 13),
          prefixIcon: _FieldIcon(icon: icon, color: hintColor),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: borderColor, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: borderColor, width: 1.6),
          ),
        ),
      ),
    );
  }
}
