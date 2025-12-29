import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  @override
  Widget build(BuildContext context) {
    if (docId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('상세보기', style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.black),
          elevation: 1,
        ),
        body: const Center(child: Text('문서 ID가 전달되지 않았습니다.')),
      );
    }

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc('tHuRzoBNhPhONwrBeUME')
        .collection('wardrobe')
        .doc(docId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('상세보기', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '카테고리: ${data['categoryId']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                          title: const Text('삭제 확인'),
                          content: const Text('삭제하시겠습니까?'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context, false); // 취소
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white, // 흰 배경
                                foregroundColor: Colors.black, // 검정 글씨
                                side: const BorderSide(
                                  color: Colors.black,
                                ), // 검정 테두리
                              ),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context, true); // 확인(삭제)
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFFCAD83B),
                                // 초록 배경
                                foregroundColor: Colors.black,
                              ),
                              child: const Text('삭제'),
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
                    '삭제',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // 수정 버튼 (오른쪽)
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: 수정 화면으로 이동
                    // 예: context.push('/wardrobe/edit', extra: docId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCAD83B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    '수정',
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
