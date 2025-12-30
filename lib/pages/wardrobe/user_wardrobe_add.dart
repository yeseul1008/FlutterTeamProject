import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UserWardrobeAdd extends StatefulWidget {
  const UserWardrobeAdd({super.key});

  @override
  State<UserWardrobeAdd> createState() => _UserWardrobeAddState();
}

class _UserWardrobeAddState extends State<UserWardrobeAdd> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? userId = FirebaseAuth.instance.currentUser?.uid;

  String? selectedCategoryId;
  String? selectedCategoryName;

  bool spring = false;
  bool summer = false;
  bool fall = false;
  bool winter = false;

  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController storeCtrl = TextEditingController();
  final TextEditingController materialCtrl = TextEditingController();
  final TextEditingController commentCtrl = TextEditingController();

  File? selectedImage;
  bool isProcessingImage = false;

  // 🔹 추가: 이미지 확대/이동 컨트롤러
  final TransformationController _transformController =
  TransformationController();

  // =========================
  // remove.bg 누끼 처리
  // =========================
  Future<File> _removeBackground(File imageFile) async {
    final String apiKey = dotenv.env['REMOVE_BG_API_KEY']!;

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.remove.bg/v1.0/removebg'),
    );

    request.headers['X-Api-Key'] = apiKey;
    request.files.add(
      await http.MultipartFile.fromPath('image_file', imageFile.path),
    );
    request.fields['size'] = 'auto';

    final response = await request.send();

    if (response.statusCode != 200) {
      throw Exception('remove.bg failed');
    }

    final bytes = await response.stream.toBytes();
    final dir = await getTemporaryDirectory();
    final file =
    File('${dir.path}/nobg_${DateTime.now().millisecondsSinceEpoch}.png');

    return file.writeAsBytes(bytes);
  }

  // =========================
  // 이미지 선택 + 누끼 자동 처리
  // =========================
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() => isProcessingImage = true);

    try {
      final original = File(image.path);
      final noBgPng = await _removeBackground(original);

      setState(() {
        selectedImage = noBgPng;
        _transformController.value = Matrix4.identity(); // 🔹 중앙 초기화
      });
    } catch (e) {
      _showFailDialog();
    } finally {
      setState(() => isProcessingImage = false);
    }
  }

  void _showFailDialog() {
    if (mounted) {
      setState(() => isProcessingImage = false);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('알림'),
          content: const Text(
            '누끼화가 안되는 이미지입니다.\n다른 사진을 이용해주세요',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    });
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  Future<File> _applyTransformToImage(File originalFile) async {
    final bytes = await originalFile.readAsBytes();
    final img.Image original = img.decodeImage(bytes)!;

    // 결과 캔버스 (미리보기 박스와 동일 비율 권장)
    const int canvasSize = 800;
    final img.Image canvas =
    img.Image(width: canvasSize, height: canvasSize);

    // 흰색 배경
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));


    final Matrix4 matrix = _transformController.value;

    final double scale = matrix.getMaxScaleOnAxis();
    final double dx = matrix.storage[12];
    final double dy = matrix.storage[13];

    final int newWidth = (original.width * scale).toInt();
    final int newHeight = (original.height * scale).toInt();

    final img.Image resized =
    img.copyResize(original, width: newWidth, height: newHeight);

    // 중앙 기준 보정
    final int centerX =
        (canvas.width - resized.width) ~/ 2 + dx.toInt();
    final int centerY =
        (canvas.height - resized.height) ~/ 2 + dy.toInt();

    img.compositeImage(
      canvas,
      resized,
      dstX: centerX,
      dstY: centerY,
    );


    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/final_${DateTime.now().millisecondsSinceEpoch}.png',
    );

    await file.writeAsBytes(img.encodePng(canvas));
    return file;
  }

  @override
  Widget build(BuildContext context) {
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
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// ================= 이미지 영역 =================
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        height: 320,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black),
                          color: Colors.white,
                        ),
                        child: selectedImage == null
                            ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add_a_photo, size: 36),
                            SizedBox(height: 12),
                            Text(
                              '옷만 보이도록 촬영해주세요',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              '• 옷걸이 / 바닥에 놓고 촬영\n'
                                  '• 단색 배경에서 촬영\n'
                                  '• 인물 착용 사진은 인식이 어려워요',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                height: 1.4,
                              ),
                            ),
                          ],
                        )
                            : ClipRect(
                          child: InteractiveViewer(
                            transformationController:
                            _transformController,
                            minScale: 0.5,
                            maxScale: 4.0,
                            boundaryMargin:
                            const EdgeInsets.all(80),
                            child: Image.file(
                              selectedImage!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                      /// 🔹 자동 중앙 정렬 버튼
                      if (selectedImage != null)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _transformController.value =
                                    Matrix4.identity();
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                            ),
                            child: const Text(
                              '중앙 정렬',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                /// ================= 카테고리 =================
                const Text('*', style: TextStyle(color: Color(0xFFA88AEE))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white, // ✅ 배경 흰색
                    border: Border.all(color: Colors.black),
                  ),
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _db
                        .collection('users')
                        .doc(userId)
                        .collection('categories')
                        .orderBy('createdAt')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(),
                        );
                      }

                      final docs = snapshot.data!.docs;
                      final categories = docs
                          .map((d) => {'id': d.id, 'name': d['name']})
                          .toList();

                      return DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCategoryId,
                          hint: const Text(':: 카테고리를 선택하세요 ::'),
                          isExpanded: true,
                          dropdownColor: Colors.white, // ✅ 펼쳐지는 메뉴도 흰색
                          items: categories
                              .map(
                                (cat) => DropdownMenuItem<String>(
                              value: cat['id'] as String,
                              child: Text(
                                cat['name'] as String,
                                style: const TextStyle(color: Colors.black),
                              ),
                            ),
                          )
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              selectedCategoryId = v;
                              selectedCategoryName =
                              categories.firstWhere((e) => e['id'] == v)['name'];
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),


                const SizedBox(height: 16),

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
                _input(controller: nameCtrl),

                const SizedBox(height: 14),

                _label('구매처 *'),
                _input(controller: storeCtrl),

                const SizedBox(height: 14),

                _label('재질'),
                _input(controller: materialCtrl),

                const SizedBox(height: 14),

                _label('comment'),
                _input(controller: commentCtrl, maxLines: 3),

                const SizedBox(height: 30),

                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (selectedImage == null) {
                        _showToast('사진을 선택해주세요');
                        return;
                      }

                      // 🔥 변환 적용된 최종 이미지 생성
                      final File finalImage =
                      await _applyTransformToImage(selectedImage!);

                      final ref = FirebaseStorage.instance.ref(
                        'wardrobe_images/${DateTime.now().millisecondsSinceEpoch}.png',
                      );

                      await ref.putFile(finalImage);
                      final imageUrl = await ref.getDownloadURL();

                      await _db
                          .collection('users')
                          .doc(userId)
                          .collection('wardrobe')
                          .add({
                        'categoryId': selectedCategoryId,
                        'categoryName': selectedCategoryName,
                        'imageUrl': imageUrl,
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      _showToast('등록되었습니다');
                      context.pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCAD83B),
                      foregroundColor: Colors.black,         // 텍스트 색상
                      side: const BorderSide(color: Colors.black), // 검정 테두리
                      padding: const EdgeInsets.symmetric(
                        horizontal: 35,
                        vertical: 14,
                      ), // 크기 살짝 증가
                      textStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('add'),
                  ),

                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 40),
              ],
            ),
          ),

          if (isProcessingImage)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      '사진 처리 중입니다...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _seasonCheck(String label, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Checkbox(
          value: value,
          activeColor: Colors.black, // 체크된 상태 색상
          checkColor: Colors.white,  // 체크 표시 색상
          onChanged: (v) => onChanged(v ?? false),
        ),
        Text(label),
      ],
    );
  }


  Widget _label(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.bold));
  }

  Widget _input({
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999), // 완전 둥글게
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: Colors.black),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: Colors.black, width: 1.5),
        ),
      ),
    );
  }

}
