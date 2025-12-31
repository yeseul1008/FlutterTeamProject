import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiOutfitMakerScreen extends StatefulWidget {
  final List<String> selectedImageUrls;
  const AiOutfitMakerScreen({super.key, required this.selectedImageUrls});

  @override
  State<AiOutfitMakerScreen> createState() => _AiOutfitMakerScreenState();
}

class _AiOutfitMakerScreenState extends State<AiOutfitMakerScreen> {
  bool _isLoading = true;
  String? _generatedImageUrl;

  @override
  void initState() {
    super.initState();
    _generateCombinedImage();
  }

  Future<void> _generateCombinedImage() async {
    try {
      // 1. 제미나이에게 이미지 분석 및 프롬프트 작성 요청
      String geminiPrompt = await _fetchPromptFromGemini();

      // 2. Pollinations URL 생성
      setState(() {
        _generatedImageUrl = "https://image.pollinations.ai/prompt/${Uri.encodeComponent(geminiPrompt)}?width=800&height=1000&model=flux&nologo=true&seed=${DateTime.now().millisecondsSinceEpoch}";
        _isLoading = false;
      });
    } catch (e) {
      print("Error: $e");
    }
  }

  // 이 함수는 이전의 제미나이 API 호출 코드를 활용하여 '텍스트 응답'만 받으면 됩니다.
  Future<String> _fetchPromptFromGemini() async {
    final String apiKey = dotenv.env['AI_IMG_API'] ?? '';
    final url = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey");

    // 이미지들을 base64로 변환하여 parts 구성 (이전 코드 활용)
    List<Map<String, dynamic>> imageParts = [];
    for (var imageUrl in widget.selectedImageUrls) {
      final res = await http.get(Uri.parse(imageUrl));
      imageParts.add({
        "inline_data": {"mime_type": "image/jpeg", "data": base64Encode(res.bodyBytes)}
      });
    }

    final response = await http.post(url, headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{
            "parts": [
              {"text": "Analyze these clothes and write a detailed English image prompt for a model wearing all of them. Only return the prompt text."},
              ...imageParts
            ]
          }]
        })
    );

    final data = jsonDecode(response.body);
    return data['candidates'][0]['content']['parts'][0]['text'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI 코디네이터")),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Image.network(_generatedImageUrl!, fit: BoxFit.contain),
      ),
    );
  }
}