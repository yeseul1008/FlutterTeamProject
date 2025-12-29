import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class UserWardrobeAdd extends StatefulWidget {
  const UserWardrobeAdd({super.key});

  @override
  State<UserWardrobeAdd> createState() => _UserWardrobeAddState();
}

class _UserWardrobeAddState extends State<UserWardrobeAdd> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? userId = FirebaseAuth.instance.currentUser?.uid;

  String? selectedCategory;

  bool spring = false;
  bool summer = false;
  bool fall = false;
  bool winter = false;

  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController storeCtrl = TextEditingController();
  final TextEditingController materialCtrl = TextEditingController();
  final TextEditingController commentCtrl = TextEditingController();

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'add clothes',
          style: TextStyle(color: Colors.black),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 이미지 영역 (placeholder)
            Stack(
              children: [
                Container(
                  height: 260,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                    color: Colors.grey.shade100,
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                      color: Colors.grey.shade300,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// 카테고리 *
            const Text('*', style: TextStyle(color: Color(0xFFA88AEE))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
                color: Colors.white,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCategory,
                  hint: const Text(
                    ':: 카테고리를 선택하세요 ::',
                    style: TextStyle(color: Colors.black),
                  ),
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                  ),
                  items: ['상의', '하의', '신발', '아우터']
                      .map(
                        (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                  )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCategory = value;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// 계절 선택
            Row(
              children: [
                _seasonCheck('봄', spring, (v) => setState(() => spring = v)),
                _seasonCheck('여름', summer, (v) => setState(() => summer = v)),
                _seasonCheck('가을', fall, (v) => setState(() => fall = v)),
                _seasonCheck('겨울', winter, (v) => setState(() => winter = v)),
              ],
            ),

            const SizedBox(height: 20),

            /// 제품명 *
            _label('제품명 *'),
            _input(controller: nameCtrl),

            const SizedBox(height: 14),

            /// 구매처 *
            _label('구매처 *'),
            _input(controller: storeCtrl),

            const SizedBox(height: 14),

            /// 재질
            _label('재질'),
            _input(controller: materialCtrl),

            const SizedBox(height: 14),

            /// comment
            _label('comment'),
            _input(controller: commentCtrl, maxLines: 3),

            const SizedBox(height: 30),

            /// add 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    if (userId == null) return;

                    // =====================
                    // 1️⃣ 필수값 검증
                    // =====================

                    if (selectedCategory == null) {
                      _showToast('카테고리를 선택해주세요');
                      return;
                    }

                    if (!(spring || summer || fall || winter)) {
                      _showToast('계절을 하나 이상 선택해주세요');
                      return;
                    }

                    if (nameCtrl.text.trim().isEmpty) {
                      _showToast('제품명을 입력해주세요');
                      return;
                    }

                    if (storeCtrl.text.trim().isEmpty) {
                      _showToast('구매처를 입력해주세요');
                      return;
                    }

                    // =====================
                    // 2️⃣ 계절 리스트 생성
                    // =====================
                    final List<String> seasons = [];
                    if (spring) seasons.add('봄');
                    if (summer) seasons.add('여름');
                    if (fall) seasons.add('가을');
                    if (winter) seasons.add('겨울');

                    // =====================
                    // 3️⃣ Firestore 저장
                    // =====================
                    await _db
                        .collection('users')
                        .doc(userId)
                        .collection('wardrobe')
                        .add({
                      'categoryId': selectedCategory,
                      'season': seasons,
                      'productName': nameCtrl.text.trim(),
                      'shop': storeCtrl.text.trim(),
                      'material': materialCtrl.text.trim(),
                      'comment': commentCtrl.text.trim(),
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    _showToast('등록되었습니다');

                    await Future.delayed(const Duration(milliseconds: 300));
                    context.pop();
                  },


                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCAD83B),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 35,
                      vertical: 17,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                      side: const BorderSide(color: Colors.black),
                    ),
                  ),
                  child: const Text(
                    'add',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }

  Widget _seasonCheck(String label, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          visualDensity: VisualDensity.compact,
        ),
        Text(label),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }
}
