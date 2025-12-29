import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class UserWardrobeEdit extends StatefulWidget {
  final String? docId;

  const UserWardrobeEdit({super.key, this.docId});

  @override
  State<UserWardrobeEdit> createState() => _UserWardrobeEditState();
}

class _UserWardrobeEditState extends State<UserWardrobeEdit> {
  /// ===== 컨트롤러 =====
  final TextEditingController productNameCtrl = TextEditingController();
  final TextEditingController shopCtrl = TextEditingController();
  final TextEditingController materialCtrl = TextEditingController();
  final TextEditingController commentCtrl = TextEditingController();

  String? selectedCategory;
  String? imageUrl;

  bool spring = false;
  bool summer = false;
  bool fall = false;
  bool winter = false;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWardrobeDetail();
  }

  /// ===== Firestore 데이터 로드 =====
  Future<void> _loadWardrobeDetail() async {
    if (widget.docId == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('wardrobe')
        .doc(widget.docId)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;

    setState(() {
      imageUrl = data['imageUrl'];
      selectedCategory = data['category'];

      productNameCtrl.text = data['productName'] ?? '';
      shopCtrl.text = data['shop'] ?? '';
      materialCtrl.text = data['material'] ?? '';
      commentCtrl.text = data['comment'] ?? '';

      final List seasons = data['season'] ?? [];
      spring = seasons.contains('spring');
      summer = seasons.contains('summer');
      fall = seasons.contains('fall');
      winter = seasons.contains('winter');

      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('add clothes', style: TextStyle(color: Colors.black)),
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

            /// ===== 이미지 =====
            // Stack(
            //   children: [
            //     Container(
            //       height: 260,
            //       width: double.infinity,
            //       decoration: BoxDecoration(
            //         border: Border.all(color: Colors.black),
            //         color: Colors.grey.shade100,
            //         image: imageUrl != null
            //             ? DecorationImage(
            //           image: NetworkImage(imageUrl!),
            //           fit: BoxFit.cover,
            //         )
            //             : null,
            //       ),
            //     ),
            //   ],
            // ),

            const SizedBox(height: 20),

            /// ===== 카테고리 =====
            const Text('*', style: TextStyle(color: Color(0xFFA88AEE))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCategory,
                  isExpanded: true,
                  hint: const Text(':: 카테고리를 선택하세요 ::'),
                  items: ['상의', '하의', '신발', '아우터']
                      .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e),
                  ))
                      .toList(),
                  onChanged: (v) => setState(() => selectedCategory = v),
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// ===== 계절 =====
            Row(
              children: [
                _seasonCheck('봄', spring, (v) => setState(() => spring = v)),
                _seasonCheck('여름', summer, (v) => setState(() => summer = v)),
                _seasonCheck('가을', fall, (v) => setState(() => fall = v)),
                _seasonCheck('겨울', winter, (v) => setState(() => winter = v)),
              ],
            ),

            const SizedBox(height: 20),

            _label('제품명 *'),
            _input(controller: productNameCtrl),

            const SizedBox(height: 14),

            _label('구매처 *'),
            _input(controller: shopCtrl),

            const SizedBox(height: 14),

            _label('재질'),
            _input(controller: materialCtrl),

            const SizedBox(height: 14),

            _label('comment'),
            _input(controller: commentCtrl, maxLines: 3),

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
    return const Text(
      '',
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
    );
  }

  Widget _input({required TextEditingController controller, int maxLines = 1}) {
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
