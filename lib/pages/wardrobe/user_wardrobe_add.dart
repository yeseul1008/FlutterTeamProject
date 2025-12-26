import 'package:flutter/material.dart';
import '../../widgets/common/main_btn.dart';
import 'package:go_router/go_router.dart';

class UserWardrobeAdd extends StatefulWidget {
  const UserWardrobeAdd({super.key});

  @override
  State<UserWardrobeAdd> createState() => _UserWardrobeAddState();
}

class _UserWardrobeAddState extends State<UserWardrobeAdd> {
  String? selectedCategory;

  bool spring = false;
  bool summer = false;
  bool fall = false;
  bool winter = false;

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
          onPressed: () {
            context.pop();
          },
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
            const Text('*', style: TextStyle(color: const Color(0xFFA88AEE))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
                color: Colors.white, // ⭐ 닫혀있을 때 배경
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCategory,
                  hint: const Text(
                    ':: 카테고리를 선택하세요 ::',
                    style: TextStyle(color: Colors.black),
                  ),
                  isExpanded: true,
                  dropdownColor: Colors.white, // ⭐ 펼쳤을 때 배경색
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
            _input(),

            const SizedBox(height: 14),

            /// 구매처 *
            _label('구매처 *'),
            _input(),

            const SizedBox(height: 14),

            /// 재질
            _label('재질'),
            _input(),

            const SizedBox(height: 14),

            /// comment
            _label('comment'),
            _input(maxLines: 3),

            const SizedBox(height: 30),

            /// add 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // TODO: 저장 로직
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

  /// ⭐ 라벨 Bold 처리
  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold, // ⭐ bold 적용
      ),
    );
  }

  Widget _input({int maxLines = 1}) {
    return TextField(
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
