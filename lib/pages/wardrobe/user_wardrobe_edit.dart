import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';

class UserWardrobeEdit extends StatefulWidget {
  final String docId;

  const UserWardrobeEdit({super.key, required this.docId});

  @override
  State<UserWardrobeEdit> createState() => _UserWardrobeEditState();
}

class _UserWardrobeEditState extends State<UserWardrobeEdit> {
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
  String? imageUrl;
  bool isProcessingImage = false;

  // 이미지 확대/이동 컨트롤러
  final TransformationController _transformController = TransformationController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (userId == null) return;

    final docRef = _db.collection('users').doc(userId).collection('wardrobe').doc(widget.docId);
    final docSnap = await docRef.get();

    if (!docSnap.exists) return;
    final data = docSnap.data()!;

    setState(() {
      selectedCategoryId = data['categoryId'];
      selectedCategoryName = data['categoryName'];
      imageUrl = data['imageUrl'];
      nameCtrl.text = data['productName'] ?? '';
      storeCtrl.text = data['shop'] ?? '';
      materialCtrl.text = data['material'] ?? '';
      commentCtrl.text = data['comment'] ?? '';
      List seasons = data['season'] ?? [];
      spring = seasons.contains('봄');
      summer = seasons.contains('여름');
      fall = seasons.contains('가을');
      winter = seasons.contains('겨울');
    });
  }

  Future<File> _removeBackground(File imageFile) async {
    final String apiKey = dotenv.env['REMOVE_BG_API_KEY']!;
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.remove.bg/v1.0/removebg'),
    );
    request.headers['X-Api-Key'] = apiKey;
    request.files.add(await http.MultipartFile.fromPath('image_file', imageFile.path));
    request.fields['size'] = 'auto';
    final response = await request.send();
    if (response.statusCode != 200) throw Exception('remove.bg failed');
    final bytes = await response.stream.toBytes();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/nobg_${DateTime.now().millisecondsSinceEpoch}.png');
    return file.writeAsBytes(bytes);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => isProcessingImage = true);

    try {
      final original = File(image.path);
      final noBg = await _removeBackground(original);
      setState(() {
        selectedImage = noBg;
        _transformController.value = Matrix4.identity();
      });
    } catch (e) {
      _showFailDialog();
    } finally {
      setState(() => isProcessingImage = false);
    }
  }

  void _showFailDialog() {
    if (mounted) setState(() => isProcessingImage = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('알림'),
          content: const Text('누끼화가 안되는 이미지입니다.\n다른 사진을 이용해주세요'),
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
      SnackBar(content: Text(message), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
    );
  }

  Future<File> _applyTransformToImage(File originalFile) async {
    final bytes = await originalFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final ui.Image original = frame.image;

    const int canvasSize = 800;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, canvasSize.toDouble(), canvasSize.toDouble()));

    canvas.save();
    canvas.transform(_transformController.value.storage);

    final dx = (canvasSize - original.width) / 2;
    final dy = (canvasSize - original.height) / 2;
    canvas.drawImage(original, Offset(dx, dy), Paint());
    canvas.restore();

    final picture = recorder.endRecording();
    final ui.Image img = await picture.toImage(canvasSize, canvasSize);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/final_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(pngBytes);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null) return const Scaffold(body: Center(child: Text('로그인이 필요합니다')));

    final docRef = _db.collection('users').doc(userId).collection('wardrobe').doc(widget.docId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('수정', style: TextStyle(color: Colors.black)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => context.pop()),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// 이미지 선택/누끼 영역
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        height: 320,
                        width: double.infinity,
                        decoration: BoxDecoration(border: Border.all(color: Colors.black), color: Colors.white),
                        child: selectedImage != null
                            ? ClipRect(
                          child: InteractiveViewer(
                            transformationController: _transformController,
                            minScale: 0.5,
                            maxScale: 4.0,
                            boundaryMargin: const EdgeInsets.all(80),
                            child: Image.file(selectedImage!, fit: BoxFit.contain),
                          ),
                        )
                            : imageUrl != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(0),
                          child: Image.network(imageUrl!, fit: BoxFit.cover),
                        )
                            : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add_a_photo, size: 36),
                            SizedBox(height: 12),
                            Text(
                              '옷만 보이도록 촬영해주세요',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      if (selectedImage != null)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: ElevatedButton(
                            onPressed: () => setState(() => _transformController.value = Matrix4.identity()),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                            child: const Text('중앙 정렬', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                /// 카테고리 선택
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black)),
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _db.collection('users').doc(userId).collection('categories').orderBy('createdAt').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator());
                      final docs = snapshot.data!.docs;
                      final categories = docs.map((d) => {'id': d.id, 'name': d['name']}).toList();

                      return DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCategoryId,
                          hint: const Text(':: 카테고리를 선택하세요 ::'),
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          items: categories
                              .map(
                                (cat) => DropdownMenuItem<String>(
                              value: cat['id'] as String,
                              child: Text(cat['name'] as String, style: const TextStyle(color: Colors.black)),
                            ),
                          )
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              selectedCategoryId = v;
                              selectedCategoryName = categories.firstWhere((e) => e['id'] == v)['name'];
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
                      if (selectedCategoryId == null) {
                        _showToast('카테고리를 선택해주세요');
                        return;
                      }

                      setState(() => isProcessingImage = true);

                      try {
                        String? uploadedImageUrl = imageUrl;

                        if (selectedImage != null) {
                          final File finalImage = await _applyTransformToImage(selectedImage!);
                          final ref = FirebaseStorage.instance
                              .ref('wardrobe_images/${DateTime.now().millisecondsSinceEpoch}.png');
                          await ref.putFile(finalImage);
                          uploadedImageUrl = await ref.getDownloadURL();
                        }

                        List<String> selectedSeasons = [];
                        if (spring) selectedSeasons.add('봄');
                        if (summer) selectedSeasons.add('여름');
                        if (fall) selectedSeasons.add('가을');
                        if (winter) selectedSeasons.add('겨울');

                        await docRef.update({
                          'categoryId': selectedCategoryId,
                          'categoryName': selectedCategoryName,
                          'imageUrl': uploadedImageUrl,
                          'productName': nameCtrl.text.trim(),
                          'shop': storeCtrl.text.trim(),
                          'material': materialCtrl.text.trim(),
                          'comment': commentCtrl.text.trim(),
                          'season': selectedSeasons,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });

                        _showToast('수정되었습니다');
                        context.pop();
                      } catch (e) {
                        _showToast('업데이트 실패');
                      } finally {
                        setState(() => isProcessingImage = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCAD83B),
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                      padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 14),
                      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('저장'),
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
                    Text('사진 처리 중입니다...', style: TextStyle(color: Colors.white)),
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
          activeColor: Colors.black,
          checkColor: Colors.white,
          onChanged: (v) => onChanged(v ?? false),
        ),
        Text(label),
      ],
    );
  }

  Widget _label(String text) => Text(text, style: const TextStyle(fontWeight: FontWeight.bold));

  Widget _input({required TextEditingController controller, int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(999)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: const BorderSide(color: Colors.black)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: const BorderSide(color: Colors.black, width: 1.5)),
      ),
    );
  }
}
