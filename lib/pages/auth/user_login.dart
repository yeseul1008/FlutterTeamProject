import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0B0B0F);
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

                // 로고 원형
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFB248C6), Color(0xFF6E62FF)],
                      ),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.checkroom_outlined,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 타이틀
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

                // 아이디 라벨
                const Text(
                  '아이디',
                  style: TextStyle(color: textGrey, fontSize: 12),
                ),
                const SizedBox(height: 8),

                _InputField(
                  controller: _idController,
                  hintText: '아이디 입력',
                  icon: Icons.person_outline,
                  borderColor: border,
                  hintColor: textGrey,
                  textColor: Colors.white,
                ),
                const SizedBox(height: 16),

                // 비밀번호 라벨
                const Text(
                  '비밀번호',
                  style: TextStyle(color: textGrey, fontSize: 12),
                ),
                const SizedBox(height: 8),

                _InputField(
                  controller: _pwController,
                  hintText: '비밀번호 입력',
                  icon: Icons.lock_outline,
                  borderColor: border,
                  hintColor: textGrey,
                  textColor: Colors.white,
                  obscureText: true,
                ),
                const SizedBox(height: 18),

                // 로그인 버튼
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: 로그인 로직 연결
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
                      '로그인',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // 또는 구분선
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.white.withOpacity(0.25),
                        thickness: 1,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '또는',
                        style: TextStyle(color: textGrey, fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.white.withOpacity(0.25),
                        thickness: 1,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Google 버튼(디자인만)
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Google 로그인 연결
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 구글 아이콘 대체(패키지 없이)
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Center(
                            child: Text(
                              'G',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Google로 시작하기',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 26),

                // 하단 문구
                Center(
                  child: Text(
                    '계정을 잃으셨나요 ?',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () {
                      // TODO: 회원가입 화면 이동
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.8),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      '계정이 없으신가요? 회원가입  >',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
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
          prefixIcon: Icon(icon, color: hintColor.withOpacity(0.9), size: 20),
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
