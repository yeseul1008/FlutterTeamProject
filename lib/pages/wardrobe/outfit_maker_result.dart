import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiOutfitMakerScreen extends StatefulWidget {
  final List<String> selectedImageUrls;

  const AiOutfitMakerScreen({super.key, required this.selectedImageUrls});

  @override
  State<AiOutfitMakerScreen> createState() => _AiOutfitMakerScreenState();
}

class _AiOutfitMakerScreenState extends State<AiOutfitMakerScreen> {
  String? generatedImageUrl;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateAiImage();
  }

  // URL 이미지를 다운로드 후 File로 변환
  Future<File> _downloadImage(String url, String filename) async {
    final response = await http.get(Uri.parse(url));
    final bytes = response.bodyBytes;
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _generateAiImage() async {
    setState(() => isLoading = true);

    try {
      final dio = Dio();
      List<MultipartFile> images = [];

      // 선택된 이미지들을 MultipartFile로 변환
      for (int i = 0; i < widget.selectedImageUrls.length; i++) {
        final file = await _downloadImage(widget.selectedImageUrls[i], 'img_$i.png');
        final mp = await MultipartFile.fromFile(file.path, filename: 'img_$i.png');
        images.add(mp);
      }

      // prompt: 선택한 옷들을 입은 한 사람, 흰 배경
      final prompt = """
A full-body person wearing the selected clothes. 
Realistic style, plain white background. 
Focus on clearly showing each clothing item.
""";

      final formData = FormData.fromMap({
        "model": "gpt-image-1",
        "images": images,
        "prompt": prompt,
      });

      final response = await dio.post(
        'https://api.openai.com/v1/images/edits',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${dotenv.env['GPT_API']}',
          },
        ),
        data: formData,
      );

      final imageUrl = response.data['data'][0]['url'] as String;

      setState(() {
        generatedImageUrl = imageUrl;
        isLoading = false;
      });
    } catch (e) {
      print('AI 이미지 생성 실패: $e');
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 이미지 생성에 실패했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 착용샷'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : (generatedImageUrl != null
            ? InteractiveViewer(
          child: Image.network(generatedImageUrl!),
        )
            : const Text('이미지 생성 실패')),
      ),
    );
  }
}
