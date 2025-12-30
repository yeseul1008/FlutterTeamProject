import 'package:flutter/material.dart';

class AiOutfitResultScreen extends StatefulWidget {
  final List<String> selectedImageUrls;

  const AiOutfitResultScreen({super.key, required this.selectedImageUrls});

  @override
  State<AiOutfitResultScreen> createState() => _AiOutfitResultScreenState();
}

class _AiOutfitResultScreenState extends State<AiOutfitResultScreen> {
  String? aiOutfitImageUrl;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateAiOutfit();
  }

  // AI 합성 API 호출 예시
  Future<void> _generateAiOutfit() async {
    setState(() {
      isLoading = true;
    });

    try {
      // 예: 선택된 옷 이미지들을 AI API로 보내고 합성 이미지 URL 받기
      // 실제 API 호출 로직에 맞춰 수정 필요
      String generatedUrl = await generateAiOutfit(widget.selectedImageUrls);

      setState(() {
        aiOutfitImageUrl = generatedUrl;
      });
    } catch (e) {
      print('AI 착용샷 생성 실패: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // 예시: AI 합성 API 호출
  Future<String> generateAiOutfit(List<String> imageUrls) async {
    await Future.delayed(const Duration(seconds: 2)); // API 대기 시간 시뮬레이션
    // 실제로는 서버나 클라우드 함수 호출 후 합성 이미지 URL 반환
    return 'https://example.com/generated_outfit_image.jpg';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 착용샷 결과'),
      ),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : aiOutfitImageUrl != null
            ? Image.network(aiOutfitImageUrl!)
            : const Text('AI 착용샷 생성에 실패했습니다.'),
      ),
    );
  }
}
