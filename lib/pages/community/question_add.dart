import 'dart:io'; // File 사용
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuestionAdd extends StatefulWidget {
  const QuestionAdd({super.key});

  @override
  State<QuestionAdd> createState() => _QuestionAddState();
}

class _QuestionAddState extends State<QuestionAdd> {
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;

  /// ================================
  /// 질문 입력 컨트롤러
  final TextEditingController _questionController =
  TextEditingController();

  /// post 버튼 활성화 여부
  bool _canPost = false;

  /// 이미지 선택
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1080,
    );

    debugPrint('📸 picked image path: ${image?.path}');

    if (image != null) {
      setState(() {
        _pickedImage = image;
      });
      _checkCanPost();
    } else {
      debugPrint('❌ image picker returned null');
    }
  }
  /// ================================

  /// ================================
  /// post 버튼 활성화 체크
  void _checkCanPost() {
    final hasText = _questionController.text.trim().isNotEmpty;
    final hasImage = _pickedImage != null;

    setState(() {
      _canPost = hasText || hasImage;
    });
  }

  /// post 저장 로직 (핵심)
  Future<void> _submitPost() async {
    try {
      debugPrint('submit start');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String? imageUrl;

      // 이미지 있으면 Storage 업로드
      if (_pickedImage != null) {
        debugPrint('image upload start');
        final ref = FirebaseStorage.instance
            .ref()
            .child('question_images')
            .child(
          '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        await ref.putFile(File(_pickedImage!.path));
        imageUrl = await ref.getDownloadURL();

        debugPrint('image uploaded: $imageUrl');
      }

      // Firestore 저장
      await FirebaseFirestore.instance.collection('questions').add({
        'text': _questionController.text.trim(),
        'imageUrl': imageUrl, // imageUrl을 제대로 Firestore에 저장
        'authorId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Firestore post added');
      // 피드 이동
      if (mounted) {
        context.go('/questionFeed');
      }
    } catch (e) {
      debugPrint('post upload error: $e');
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String currentPath = GoRouterState.of(context).uri.path;

    return Container(
      color: Colors.white, // ⭐ 전체 백그라운드 흰색
      child: SafeArea(
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
                        onPressed: () => context.go('/communityMainFeed'),
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
                            fontWeight: FontWeight.w900,
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
                        onPressed: () => context.go('/questionFeed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: currentPath == '/questionFeed'
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
                            fontWeight: FontWeight.w900,
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
                        onPressed: () => context.go('/followList'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: currentPath == '/followList'
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
                            fontWeight: FontWeight.w900,
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => context.go('/questionFeed'),
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Center(
                      child: Text(
                        'ASK A QUESTION',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    /// 질문 입력
                    Container(
                      height: 120,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white, // ⭐ 입력창 배경도 흰색
                        border: Border.all(color: Colors.black),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _questionController,
                        onChanged: (_) => _checkCanPost(),
                        maxLines: null,
                        expands: true,
                        decoration: const InputDecoration(
                          hintText: 'Write your question...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    /// 이미지 추가
                    GestureDetector(
                      onTap: _pickImage,
                      child: Column(
                        children: [
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.black),
                            ),
                            child: _pickedImage == null
                                ? const Center(
                              child: Icon(Icons.add, size: 48),
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

                    /// post 버튼
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _canPost
                            ? _submitPost
                            : null,
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
                            fontWeight: FontWeight.w900,
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
      ),
    );
  }
}