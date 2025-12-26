import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common/main_btn.dart';

class FindPwd extends StatefulWidget {
  const FindPwd({super.key});

  @override
  State<FindPwd> createState() => _FindPwdState();
}

class _FindPwdState extends State<FindPwd> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  final _pwCheckController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _idController.dispose();
    _pwController.dispose();
    _pwCheckController.dispose();
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

                // 로고
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

                Center(
                  child: Text(
                    'What you where?',
                    style: const TextStyle(
                      color: textGrey,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // 전화번호
                const Text('전화번호',
                    style: TextStyle(color: textGrey, fontSize: 12)),
                const SizedBox(height: 8),
                _InputField(
                  controller: _phoneController,
                  hintText: '인증할 계정의 전화번호를 입력하세요',
                  icon: Icons.call_outlined,
                  borderColor: border,
                  hintColor: textGrey,
                  textColor: Colors.white,
                  keyboardType: TextInputType.phone,
                ),

                const SizedBox(height: 16),

                // 인증번호
                const Text('인증번호 입력',
                    style: TextStyle(color: textGrey, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _InputField(
                        controller: _codeController,
                        hintText: '인증번호 6자리 입력',
                        icon: Icons.verified_user_outlined,
                        borderColor: border,
                        hintColor: textGrey,
                        textColor: Colors.white,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 44,
                      width: 80,
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO 인증번호 확인
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
                          '확인',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 아이디
                const Text('아이디',
                    style: TextStyle(color: textGrey, fontSize: 12)),
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

                // 비밀번호
                const Text('비밀번호',
                    style: TextStyle(color: textGrey, fontSize: 12)),
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

                const SizedBox(height: 16),

                // 비밀번호 재입력
                const Text('비밀번호 재입력',
                    style: TextStyle(color: textGrey, fontSize: 12)),
                const SizedBox(height: 8),
                _InputField(
                  controller: _pwCheckController,
                  hintText: '비밀번호 재입력',
                  icon: Icons.lock_outline,
                  borderColor: border,
                  hintColor: textGrey,
                  textColor: Colors.white,
                  obscureText: true,
                ),

                const SizedBox(height: 26),

                // 변경 완료 버튼 (로직 비움)
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: 비밀번호 변경 처리
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '변경 완료하기',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
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
        style: TextStyle(color: textColor, fontSize: 14),
        cursorColor: borderColor,
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintStyle: TextStyle(
            color: hintColor.withOpacity(0.7),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            icon,
            color: hintColor.withOpacity(0.9),
            size: 20,
          ),
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
