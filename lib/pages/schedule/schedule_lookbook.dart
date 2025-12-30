import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';


class ScheduleLookbook extends StatefulWidget {
  const ScheduleLookbook({super.key});

  @override
  State<ScheduleLookbook> createState() => _UserLookbookState();
}

class _UserLookbookState extends State<ScheduleLookbook> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final userId = FirebaseAuth.instance.currentUser?.uid;

  List<Map<String, dynamic>> lookbooks = []; // 모든 문서 저장
  bool loading = true;

  // 사용자 룩북 불러오기
  Future<void> _getUserLookbook() async {
    try {
      final querySnapshot = await fs
          .collection('lookbooks')
          .where('userId', isEqualTo: userId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final dataList = querySnapshot.docs.map((doc) {
          final data = doc.data();
          data['docId'] = doc.id; // 상세보기 이동용 문서 ID 추가
          return data;
        }).toList();

        setState(() {
          lookbooks = dataList;
          loading = false;
        });
      } else {
        setState(() {
          lookbooks = [];
          loading = false;
        });
        print('User not found');
      }
    } catch (e) {
      setState(() {
        loading = false;
      });
      print('Error fetching user info: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _getUserLookbook();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: SizedBox(
          height: 44,
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/userLookbookAdd'),
            backgroundColor: const Color(0xFFCAD83B),
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: Colors.black),
            ),
            icon: const Icon(
              Icons.add,
              size: 18,
              color: Colors.black,
            ),
            label: const Text(
              '등록 완료하기',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 30),

            // 상단 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/AddSchedule'),
                    icon: const Icon(Icons.arrow_back_ios_new),
                  ),
                  Expanded(
                      child: Center(
                          child: Text(
                            '나의 룩북',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),)
                      )
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 검색 바 (정적)
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

            // 룩북 그리드
            loading
                ? const Expanded(
                child: Center(child: CircularProgressIndicator()))
                : lookbooks.isEmpty
                ? const Expanded(
                child: Center(child: Text('등록된 룩북이 없습니다.')))
                : Expanded(
              child: GridView.builder(
                itemCount: lookbooks.length,
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.7,
                ),
                itemBuilder: (context, index) {
                  final item = lookbooks[index];
                  final imageUrl = item['imageUrl'] ?? '';

                  return GestureDetector(
                    onTap: () {
                    },
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            color: Colors.white,
                          ),
                          child: imageUrl != ''
                              ? ClipRRect(
                            borderRadius:
                            BorderRadius.circular(8),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          )
                              : null,
                        ),
                      ],
                    ),
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
