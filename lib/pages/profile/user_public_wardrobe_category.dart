import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 카테고리 이름 → asset 이미지 매핑
const Map<String, String> categoryImageMap = {
  'outer': 'assets/categories/outer.png',
  'top': 'assets/categories/top.png',
  'bottom': 'assets/categories/bottom.png',
  'dress': 'assets/categories/dress.png',
  'shoes': 'assets/categories/shoes.png',
  'accessories': 'assets/categories/accessories.png',
};

class UserPublicWardrobeCategory extends StatelessWidget {
  final void Function(String categoryId) onSelect;
  final String targetUserId;

  const UserPublicWardrobeCategory({
    super.key,
    required this.onSelect,
    required this.targetUserId,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;  // CHANGED: renamed for clarity
    final isOwnProfile = currentUserId == targetUserId;  // NEW: check if viewing own profile

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)  // Using targetUserId
          .collection('categories')
          .orderBy('createdAt')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        final categories = docs.map((d) => {
          'name': d['name'],
          'isDefault': d['isDefault'] ?? false,
          'id': d.id,
        }).toList();

        return GestureDetector(
          onTap: () => Navigator.pop(context),
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.88,
                height: MediaQuery.of(context).size.height * 0.75,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: categories.isEmpty
                      ? const Center(
                    child: Text(
                      '카테고리가 없습니다',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                      : GridView.builder(
                    itemCount: categories.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemBuilder: (context, index) {
                      final doc = categories[index];
                      final name = doc['name'] as String;
                      final isDefault = doc['isDefault'] as bool? ?? false;
                      final docId = doc['id'] as String;

                      return GestureDetector(
                        onTap: () {
                          onSelect(name);
                        },
                        child: Stack(
                          children: [
                            Column(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: categoryImageMap.containsKey(name)
                                          ? Image.asset(
                                        categoryImageMap[name]!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      )
                                          : Container(
                                        color: Colors.grey.shade400,
                                        child: const Center(
                                          child: Icon(
                                            Icons.category,
                                            size: 30,
                                          ),
                                        ),
                                      ),
                                    ),
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
                            // CHANGED: Only show delete button if viewing own profile AND not default
                            if (isOwnProfile && !isDefault)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () async {
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(targetUserId)  // CHANGED: use targetUserId
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
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
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
            ),
          ),
        );
      },
    );
  }
}