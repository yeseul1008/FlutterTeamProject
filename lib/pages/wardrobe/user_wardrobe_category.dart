import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserWardrobeCategory extends StatelessWidget {
  final void Function(String categoryId) onSelect; // 문서 ID 반환

  const UserWardrobeCategory({
    super.key,
    required this.onSelect,
  });

  Future<void> _showAddCategoryDialog(BuildContext context) async {
    final TextEditingController ctrl = TextEditingController();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final fs = FirebaseFirestore.instance;

    if (userId == null) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.black),
          ),
          title: const Text(
            '카테고리 추가',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: '카테고리 이름 입력',
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소', style: TextStyle(color: Colors.black)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () async {
                final value = ctrl.text.trim();
                if (value.isEmpty) return;

                await fs
                    .collection('users')
                    .doc(userId)
                    .collection('categories')
                    .add({
                  'name': value,
                  'isDefault': false,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                Navigator.pop(dialogContext);
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('categories')
          .orderBy('createdAt')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;

        // categories 컬렉션 앞에 "all" 추가
        final categories = [
          {'name': 'all', 'isDefault': true, 'id': 'all'},
          ...docs.map((d) => {
            'name': d['name'],
            'isDefault': d['isDefault'] ?? false,
            'id': d.id,
          }),
          null, // 마지막 add 버튼
        ];

        return Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.88,
            height: MediaQuery.of(context).size.height * 0.75,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: GridView.builder(
                itemCount: categories.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final doc = categories[index];
                  final isAdd = doc == null;
                  final name = isAdd ? 'add' : doc['name'] as String;
                  final isDefault = !isAdd && (doc['isDefault'] as bool? ?? false);
                  final docId = !isAdd ? doc['id'] as String : null;

                  return GestureDetector(
                    onTap: () {
                      if (isAdd) {
                        _showAddCategoryDialog(context);
                      } else {
                        Navigator.pop(context);
                        onSelect(docId!); // 문서 ID 전달
                      }
                    },
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isAdd ? Colors.black : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: isAdd
                                    ? const Center(
                                  child: Icon(Icons.add, size: 36, color: Colors.white),
                                )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if (!isAdd && !isDefault)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () async {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userId)
                                    .collection('categories')
                                    .doc(docId)
                                    .delete();
                              },
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(Icons.close, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
