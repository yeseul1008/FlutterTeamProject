import 'package:flutter/material.dart';
import '../../widgets/common/main_btn.dart';
import 'package:go_router/go_router.dart';

class UserScrap extends StatelessWidget {
  const UserScrap({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 30),

            // 상단 버튼 3개 (ElevatedButton)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50, // ⭐ 버튼 높이 증가
                    child: ElevatedButton(
                      onPressed: () => context.go('/userWardrobeList'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: EdgeInsets.zero, // 높이 정확히 맞춤
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: const BorderSide(color: Colors.black),
                        ),
                      ),
                      child: const Text(
                        'closet',
                        style: TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => context.go('/userLookbook'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: const BorderSide(color: Colors.black),
                        ),
                      ),
                      child: const Text(
                        'lookbooks',
                        style: TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => context.go('/userScrap'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCAD83B),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: const BorderSide(color: Colors.black),
                        ),
                      ),
                      child: const Text(
                        'scrap',
                        style: TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),


            const SizedBox(height: 16),

            // 검색 바 영역 (정적)
            Row(
              children: [
                const Icon(Icons.menu),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: const [
                        Expanded(
                          child: Text(
                            'search...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        Icon(Icons.search, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

              ],
            ),

            const SizedBox(height: 16),

            // 옷 그리드 (빈 공간)
            Expanded(
              child: GridView.builder(
                itemCount: 12,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.7,
                ),
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          color: Colors.white,
                        ),
                      ),
                      const Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(
                          Icons.favorite_border,
                          size: 18,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
