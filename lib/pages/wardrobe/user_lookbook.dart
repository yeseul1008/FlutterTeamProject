import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserLookbook extends StatefulWidget {
  const UserLookbook({super.key});

  @override
  State<UserLookbook> createState() => _UserLookbookState();
}

class _UserLookbookState extends State<UserLookbook> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final userId = FirebaseAuth.instance.currentUser?.uid;

  List<Map<String, dynamic>> lookbooks = []; // 모든 문서 저장
  bool loading = true;

  // 검색
  TextEditingController searchController = TextEditingController();
  String searchText = '';

  // 사용자 룩북 불러오기
  Future<void> _getUserLookbook() async {
    try {
      final querySnapshot = await fs
          .collection('lookbooks')
          .where('userId', isEqualTo: userId)
          .get();

      final dataList = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id; // 상세보기 이동용 문서 ID 추가
        return data;
      }).toList();

      setState(() {
        lookbooks = dataList;
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });
      print('Error fetching user lookbooks: $e');
    }
  }

// 클릭시 모달
  Future<void> _showLookbookModal(Map<String, dynamic> item) async {
    final docId = item['docId'] as String?;
    final imageUrl = item['resultImageUrl'] as String? ?? '';
    final alias = item['alias'] as String? ?? '';

    if (docId == null || imageUrl.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  alias,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) {
                            return AlertDialog(
                              title: const Text('삭제 확인'),
                              content: const Text('정말 삭제하시겠습니까?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('취소'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('삭제', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirm == true) {
                          try {
                            await fs.collection('lookbooks').doc(docId).delete();
                            setState(() {
                              lookbooks.removeWhere((e) => e['docId'] == docId);
                            });
                            Navigator.of(ctx).pop(); // 모달 닫기
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('룩북이 삭제되었습니다.')),
                            );
                          } catch (e) {
                            print('삭제 실패: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('삭제 실패')),
                            );
                          }
                        }
                      },
                      child: const Text('삭제'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop(); // 닫기
                      },
                      child: const Text('닫기'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _getUserLookbook();
  }

  @override
  Widget build(BuildContext context) {
    // 검색 적용
    final filteredLookbooks = lookbooks.where((item) {
      final alias = (item['alias'] ?? '').toString().toLowerCase();
      return alias.contains(searchText.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
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
              'add lookbook',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 10),

              // 상단 버튼 3개
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => context.go('/userWardrobeList'),
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
                          'closet',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20),
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
                          'lookbooks',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
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
                          'scrap',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 검색 바
              Row(
                children: [
                  // const Icon(Icons.menu),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: searchController,
                        onChanged: (value) {
                          setState(() {
                            searchText = value.trim();
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'search...',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.search, size: 28),
                ],
              ),

              const SizedBox(height: 16),

              // 룩북 그리드
              loading
                  ? const Expanded(
                  child: Center(child: CircularProgressIndicator()))
                  : filteredLookbooks.isEmpty
                  ? const Expanded(
                  child: Center(child: Text('검색 결과가 없습니다.')))
                  : Expanded(
                child: GridView.builder(
                  itemCount: filteredLookbooks.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8, // 이미지 + alias 공간 확보
                  ),
                  itemBuilder: (context, index) {
                    final item = filteredLookbooks[index];
                    final imageUrl = item['resultImageUrl'] ?? '';
                    final alias = item['alias'] ?? '';
                    final type = item['type'] ?? '';

                    return GestureDetector(
                      onTap: () => _showLookbookModal(item),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                color: Colors.white,
                              ),
                              child: imageUrl != ''
                                  ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (type == 'ai_generated')
                                const Icon(
                                  Icons.auto_awesome,
                                  size: 12,
                                  color: Color(0xFFA88AEE), // Your purple color
                                ),
                              if (type == 'ai_generated')
                                const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  alias,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
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
      ),
    );
  }
}
