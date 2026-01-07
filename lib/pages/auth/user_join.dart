import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  String _gender = 'M';

  bool _loading = false;
  bool _checkingId = false;
  bool _isIdChecked = false;
  bool _isIdAvailable = false;
  String _idCheckMessage = '';

  // 닉네임 중복확인 관련
  bool _checkingNickname = false;
  bool _isNicknameChecked = false;
  bool _isNicknameAvailable = false;
  String _nicknameCheckMessage = '';

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

  /// 아이디 중복 확인
  Future<void> _checkLoginId() async {
    final loginId = _loginId.text.trim();

    if (loginId.isEmpty) {
      setState(() {
        _isIdChecked = false;
        _isIdAvailable = false;
        _idCheckMessage = '';
      });
      return;
    }

    if (loginId.length < 4) {
      setState(() {
        _isIdChecked = true;
        _isIdAvailable = false;
        _idCheckMessage = '아이디는 4자 이상이어야 합니다';
      });
      return;
    }

    setState(() => _checkingId = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('loginId', isEqualTo: loginId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _isIdChecked = true;
          _isIdAvailable = true;
          _idCheckMessage = '사용 가능한 아이디입니다';
        });
      } else {
        setState(() {
          _isIdChecked = true;
          _isIdAvailable = false;
          _idCheckMessage = '이미 사용 중인 아이디입니다';
        });
      }
    } catch (e) {
      setState(() {
        _isIdChecked = true;
        _isIdAvailable = false;
        _idCheckMessage = '아이디 확인 중 오류가 발생했습니다';
      });
    } finally {
      setState(() => _checkingId = false);
    }
  }

  /// 닉네임 중복 확인
  Future<void> _checkNickname() async {
    final nickname = _nickname.text.trim();

    if (nickname.isEmpty) {
      setState(() {
        _isNicknameChecked = false;
        _isNicknameAvailable = false;
        _nicknameCheckMessage = '';
      });
      return;
    }

    if (nickname.length < 2) {
      setState(() {
        _isNicknameChecked = true;
        _isNicknameAvailable = false;
        _nicknameCheckMessage = '닉네임은 2자 이상이어야 합니다';
      });
      return;
    }

    setState(() => _checkingNickname = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('nickname', isEqualTo: nickname)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _isNicknameChecked = true;
          _isNicknameAvailable = true;
          _nicknameCheckMessage = '사용 가능한 닉네임입니다';
        });
      } else {
        setState(() {
          _isNicknameChecked = true;
          _isNicknameAvailable = false;
          _nicknameCheckMessage = '이미 사용 중인 닉네임입니다';
        });
      }
    } catch (e) {
      setState(() {
        _isNicknameChecked = true;
        _isNicknameAvailable = false;
        _nicknameCheckMessage = '닉네임 확인 중 오류가 발생했습니다';
      });
    } finally {
      setState(() => _checkingNickname = false);
    }
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

    // 아이디 중복확인 필수 체크
    if (!_isIdChecked || !_isIdAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이디 중복확인을 해주세요.')),
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

      await _fs.createUser(
        userId: uid,
        loginId: loginId,
        email: email,
        phone: phone,
        provider: 'email',
        nickname: nickname,
        profileImageUrl: null,
        gender: _gender,
      );

      await _fs.initFollowDoc(uid);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('회원가입이 완료되었습니다!'),
          backgroundColor: Colors.green,
        ),
      );
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
                    width: 150,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  '성별',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: _GenderSelectItem(
                        label: '여성',
                        value: 'female',
                        groupValue: _gender,
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _GenderSelectItem(
                        label: '남성',
                        value: 'male',
                        groupValue: _gender,
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

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
                Row(
                  children: [
                    Expanded(
                      child: _InputField(
                        controller: _nickname,
                        hintText: '닉네임 입력 (2자 이상)',
                        icon: Icons.person_outline,
                        borderColor: border,
                        hintColor: textGrey,
                        textColor: Colors.white,
                        onChanged: (value) {
                          // 닉네임이 변경되면 중복확인 초기화
                          if (_isNicknameChecked) {
                            setState(() {
                              _isNicknameChecked = false;
                              _isNicknameAvailable = false;
                              _nicknameCheckMessage = '';
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _checkingNickname ? null : _checkNickname,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: purple,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: _checkingNickname
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Text(
                          '중복확인',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // 닉네임 중복확인 결과 메시지
                if (_nicknameCheckMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Row(
                      children: [
                        Icon(
                          _isNicknameAvailable ? Icons.check_circle : Icons.cancel,
                          size: 14,
                          color: _isNicknameAvailable ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _nicknameCheckMessage,
                          style: TextStyle(
                            fontSize: 11,
                            color: _isNicknameAvailable ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // 아이디 입력 필드 + 중복확인 버튼
                const Text('아이디', style: TextStyle(color: Colors.black, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _InputField(
                        controller: _loginId,
                        hintText: '아이디 입력 (4자 이상)',
                        icon: Icons.account_circle_outlined,
                        borderColor: border,
                        hintColor: textGrey,
                        textColor: Colors.white,
                        onChanged: (value) {
                          // 아이디가 변경되면 중복확인 초기화
                          if (_isIdChecked) {
                            setState(() {
                              _isIdChecked = false;
                              _isIdAvailable = false;
                              _idCheckMessage = '';
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _checkingId ? null : _checkLoginId,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: purple,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: _checkingId
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Text(
                          '중복확인',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // 중복확인 결과 메시지
                if (_idCheckMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Row(
                      children: [
                        Icon(
                          _isIdAvailable ? Icons.check_circle : Icons.cancel,
                          size: 14,
                          color: _isIdAvailable ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _idCheckMessage,
                          style: TextStyle(
                            fontSize: 11,
                            color: _isIdAvailable ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
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
                          fontWeight: FontWeight.bold),
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
  final ValueChanged<String>? onChanged;

  const _InputField({
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.borderColor,
    required this.hintColor,
    required this.textColor,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: Colors.black,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF2F2F2),

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

class _GenderSelectItem extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  const _GenderSelectItem({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool selected = value == groupValue;

    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEDE7FF) : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF7B64D6) : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF7B64D6) : Colors.black87,
          ),
        ),
      ),
    );
  }
}