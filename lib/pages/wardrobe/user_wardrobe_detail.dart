import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class UserWardrobeDetail extends StatelessWidget {
  final String? docId;

  const UserWardrobeDetail({super.key, this.docId});

  // 읽기 전용 텍스트 필드
  Widget _readonlyField(String label, String value) {
    return TextField(
      readOnly: true,
      controller: TextEditingController(text: value),
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }

  // 날짜 포맷
  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

// 카테고리 이름 가져오기 함수
  Future<String?> _getCategoryName(String userId, String categoryId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('categories')
        .doc(categoryId)
        .get();

    if (doc.exists) {
      return doc.data()?['name'] as String?;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (docId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            '상세보기',
            style: TextStyle(color: Colors.black),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white, // 🔴 핵심 (Material 3)
          iconTheme: const IconThemeData(color: Colors.black),

          elevation: 0,                   // 그림자 제거
          shadowColor: Colors.transparent, // 잔상 제거
          scrolledUnderElevation: 0,       // 스크롤 시 색 변형 방지
        ),

        body: const Center(child: Text('문서 ID가 전달되지 않았습니다.')),
      );
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('로그인이 필요합니다')),
      );
    }

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('wardrobe')
        .doc(docId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('상세보기', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: docRef.get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('해당 옷 정보가 없습니다.'));
          }

          final data = snapshot.data!.data()!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 카테고리 출력
                if (data['categoryId'] != null && data['categoryId'] != '')
                  FutureBuilder<String?>(
                    future: _getCategoryName(userId, data['categoryId']),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text('카테고리: 로딩중...',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data == null) {
                        return const SizedBox.shrink(); // 없으면 그냥 안 보여줌
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '카테고리: ${snapshot.data}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),


                // 이미지 출력
                if (data['imageUrl'] != null && data['imageUrl'] != '')
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        data['imageUrl'],
                        width: double.infinity,
                        height: 300,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // 제품명
                if (data['productName'] != null && data['productName'] != '')
                  Text(
                    '제품명: ${data['productName']}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 16),

                // 계절, 샵, 소재, 코멘트
                if (data['season'] != null)
                  _readonlyField(
                    '계절',
                    data['season'] is List
                        ? (data['season'] as List).join(', ')
                        : data['season'].toString(),
                  ),
                const SizedBox(height: 12),
                if (data['shop'] != null && data['shop'] != '')
                  _readonlyField('샵', data['shop']),
                const SizedBox(height: 12),
                if (data['material'] != null && data['material'] != '')
                  _readonlyField('소재', data['material']),
                const SizedBox(height: 12),
                if (data['comment'] != null && data['comment'] != '')
                  _readonlyField('코멘트', data['comment']),
                const SizedBox(height: 24),

                Center(
                  child: Text(
                    '추가한 날짜: ${_formatDate(data['createdAt'])}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16, // 글씨 크기 증가
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // 삭제 버튼 (왼쪽)
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final bool? confirm = await showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          backgroundColor: Colors.white,
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),

                          title: const Text(
                            'Confirm',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),

                          content: const Text(
                            '삭제하시겠습니까?\n삭제 후에는 되돌릴 수 없습니다.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),

                          actions: [
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.pop(context, false);
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.black,
                                      side: const BorderSide(color: Colors.black),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context, true);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFCAD83B),
                                      foregroundColor: Colors.black,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );


                      },
                    );

                    // 확인 버튼을 눌렀을 때만 삭제
                    if (confirm == true) {
                      await docRef.delete();
                      Navigator.pop(context);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // 수정 버튼 (오른쪽)
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (docId == null) return;

                    context.push(
                      '/userWardrobeEdit',
                      extra: docId, // 🔑 문서 ID 전달
                    );
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCAD83B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
