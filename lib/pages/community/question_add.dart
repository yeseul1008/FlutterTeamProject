import 'dart:io'; // File 사용
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// Stateless → Stateful (이미지 상태 필요)
class QuestionAdd extends StatefulWidget {
  const QuestionAdd({super.key});

  @override
  State<QuestionAdd> createState() => _QuestionAddState();
}

class _QuestionAddState extends State<QuestionAdd> {
  /// [추가] 이미지 피커 & 선택된 이미지
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;

  /// [추가] 이미지 선택 함수
  Future<void> _pickImage() async {
    final XFile? image =
    await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _pickedImage = image;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentPath =
        GoRouterState.of(context).uri.path;

    return SafeArea(
      child: Column(
        children: [
          /// ===== 상단 UI (기존 그대로) =====
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () =>
                          context.go('/communityMainFeed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        currentPath == '/communityMainFeed'
                            ? const Color(0xFFCAD83B)
                            : Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: const BorderSide(color: Colors.black),
                        ),
                      ),
                      child: const Text(
                        'Feed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () =>
                          context.go('/questionFeed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        currentPath == '/questionFeed'
                            ? const Color(0xFFCAD83B)
                            : Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: const BorderSide(color: Colors.black),
                        ),
                      ),
                      child: const Text(
                        'QnA',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () =>
                          context.go('/followList'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        currentPath == '/followList'
                            ? const Color(0xFFCAD83B)
                            : Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: const BorderSide(color: Colors.black),
                        ),
                      ),
                      child: const Text(
                        'Follow',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// ===== Body =====
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  /// 닫기 버튼
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          context.go('/questionFeed'),
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Center(
                    child: Text(
                      'ASK A QUESTION',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  /// 질문 입력 박스
                  Container(
                    height: 120,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const TextField(
                      maxLines: null,
                      expands: true,
                      decoration: InputDecoration(
                        hintText: 'Write your question...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  ///  [수정] 이미지 추가 + 미리보기
                  GestureDetector(
                    onTap: _pickImage, // 클릭 시 갤러리
                    child: Column(
                      children: [
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black),
                          ),
                          child: _pickedImage == null
                              ? const Center(
                            child: Icon(
                              Icons.add,
                              size: 48,
                            ),
                          )
                              : Image.file(
                            File(_pickedImage!.path),
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'add an image',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  /// Post 버튼
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        /// 다음 단계:
                        /// 1. Firebase Storage 업로드
                        /// 2. Firestore에 질문 + 이미지 URL 저장
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCAD83B),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'post',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
