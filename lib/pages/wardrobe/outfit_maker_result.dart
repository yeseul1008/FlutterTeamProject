import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class AiOutfitMakerScreen extends StatefulWidget {
  final List<String> selectedImageUrls;
  const AiOutfitMakerScreen({super.key, required this.selectedImageUrls});

  @override
  State<AiOutfitMakerScreen> createState() => _AiOutfitMakerScreenState();
}

class _AiOutfitMakerScreenState extends State<AiOutfitMakerScreen> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  bool _isLoading = true;
  String? _generatedImageUrl;
  String? _errorMessage;
  String _currentStep = "이미지 분석 중...";
  Map<String, dynamic> userInfo = {};
  String? gender;
  TextEditingController _AILookbookName = TextEditingController();

  Future <void> _getUserInfo () async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final userSnapshot = await fs.collection('users').doc(uid).get();

    setState(() {
      userInfo = userSnapshot.data() ?? {'userId': uid};
      gender = userInfo['gender'];
    });

    print("User's gender is : $gender");
  }

  @override
  void initState() {
    super.initState();
    _generateCombinedImage();
    _getUserInfo();
  }

  Future<void> _generateCombinedImage() async {
    try {
      setState(() => _currentStep = "AI가 옷을 분석하고 있습니다...");
      String geminiPrompt = await _fetchPromptFromGemini();

      print("Generated prompt: $geminiPrompt");

      setState(() => _currentStep = "AI 룩북 이미지를 생성하고 있습니다...");

      // You can simplify the prompt now since we'll crop afterwards
      final enhancedPrompt = "$geminiPrompt, Korean e-commerce fashion photography style, ${gender} model standing straight with relaxed arms, pure white seamless background, no floor visible, professional clean product photo, full body shot, sharp focus, even lighting, isolated on white --no shadows --no studio --no props --no floor line --no background gradient";

      final generatedUrl = "https://image.pollinations.ai/prompt/${Uri.encodeComponent(enhancedPrompt)}?width=600&height=900&model=flux-realism&nologo=true&seed=${DateTime.now().millisecondsSinceEpoch}";

      // Download and crop the image
      setState(() => _currentStep = "이미지를 다운로드하고 처리하는 중...");
      final response = await http.get(Uri.parse(generatedUrl));

      if (response.statusCode != 200) {
        throw Exception('Failed to load image');
      }

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/ai_outfit_temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(response.bodyBytes);

      // Crop the image to remove head
      final croppedFile = await cropImageToNeck(tempFile);

      // Read cropped file as bytes for display
      final croppedBytes = await croppedFile.readAsBytes();
      final croppedBase64 = base64Encode(croppedBytes);

      setState(() {
        _generatedImageUrl = 'data:image/jpeg;base64,$croppedBase64';
        _isLoading = false;
        _currentStep = "완료!";
      });
    } catch (e) {
      print("Error: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = "AI 룩북 생성에 실패했습니다. 다시 시도해주세요.\n\n오류: $e";
      });
    }
  }

  Future<String> _fetchPromptFromGemini() async {
    final apiKey = dotenv.env['AI_IMG_API'] ?? '';

    if (apiKey.isEmpty) {
      throw Exception('API key not found');
    }

    print("Creating Gemini model...");

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
    );

    print("Converting ${widget.selectedImageUrls.length} images...");
    final imageParts = <DataPart>[];

    for (int i = 0; i < widget.selectedImageUrls.length; i++) {
      print("Downloading image ${i + 1}...");
      final res = await http.get(Uri.parse(widget.selectedImageUrls[i]));

      if (res.statusCode == 200) {
        imageParts.add(DataPart('image/jpeg', res.bodyBytes));
        print("Image ${i + 1} added successfully");
      }
    }

    if (imageParts.isEmpty) {
      throw Exception('No valid images to analyze');
    }

    final textPrompt = TextPart(
        'Analyze these clothing items. Create an image generation prompt for: A fashion model standing perfectly straight with arms relaxed at sides, front-facing view, full body shot showing head to toe including shoes. The model should wear ALL these clothing items together. Style: Clean Korean fashion e-commerce product photo with PURE WHITE seamless background (like StyleNanda, Ader Error, or W Concept product photos). No floor line visible, no shadows on background, model should appear to float on white. Professional lighting, sharp focus on clothing details.'
    );

    print("Sending request to Gemini...");

    try {
      final response = await model.generateContent([
        Content.multi([textPrompt, ...imageParts])
      ]);

      if (response.text == null || response.text!.isEmpty) {
        throw Exception('Empty response from Gemini');
      }

      print("Generated prompt: ${response.text}");
      return response.text!;

    } catch (e) {
      final errorMsg = e.toString();

      // Check if it's a rate limit error
      if (errorMsg.contains('quota') || errorMsg.contains('rate limit')) {
        // Extract wait time from error message (default to 60 seconds)
        int waitSeconds = 60;
        final match = RegExp(r'retry in (\d+)').firstMatch(errorMsg);
        if (match != null) {
          waitSeconds = double.parse(match.group(1)!).ceil();
        }

        print("Rate limit hit. Waiting $waitSeconds seconds...");

        // Show user-friendly message
        throw Exception('Gemini API 사용량 초과. ${waitSeconds}초 후에 다시 시도해주세요.');
      }

      print("Gemini API Error: $e");
      throw Exception('Failed to generate prompt: $e');
    }
  }

  // Save AI outfit to Firebase
  Future<void> _saveOutfitToFirebase() async {
    if (_generatedImageUrl == null) return;

    if (_AILookbookName.text.trim().isEmpty) {
      _showSnack('Enter a name for your outfit !');
      return;
    }

    setState(() => _currentStep = "저장 중...");

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _showSnack('로그인이 필요합니다');
        return;
      }

      // Decode base64 image
      final base64String = _generatedImageUrl!.split(',')[1];
      final imageBytes = base64Decode(base64String);

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/ai_outfit_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(imageBytes);

      // Upload to Firebase Storage
      final fileName = 'ai_outfit_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance
          .ref('ai_outfits/$uid/$fileName');

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('lookbooks')
          .add({
        'userId': uid,
        'resultImageUrl': downloadUrl,
        'type': 'ai_generated',
        'sourceImages': widget.selectedImageUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'inLookbook': true,
        'publishToCommunity': false,
        'alias' : _AILookbookName.text.trim(),
      });

      _showSnack('AI 룩북이 저장되었습니다!');

      await Future.delayed(Duration(milliseconds: 800));

      if(!mounted) return;
      context.pop();

    } catch (e) {
      print('Error saving outfit: $e');
      _showSnack('저장에 실패했습니다: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("AI generated look"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_generatedImageUrl != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _generatedImageUrl = null;
                  _errorMessage = null;
                });
                _generateCombinedImage();
              },
              tooltip: '다시 생성',
            ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              _currentStep,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),
            const Text(
              '잠시만 기다려주세요...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      )
          : _errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 20),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _generateCombinedImage();
                },
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      )
          : SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Generated Image (displaying base64)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Image.memory(
                base64Decode(_generatedImageUrl!.split(',')[1]),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 500,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 20),
                        const Text('이미지 로드 실패'),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _generatedImageUrl = null;
                            });
                            _generateCombinedImage();
                          },
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // "Outfit complete!" text
            const Text(
              'Outfit complete!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Enter name of the AI lookbook
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _AILookbookName,
                decoration: InputDecoration(
                  label: Text('Name your outfit'),
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 3),

            // Download icon button
            IconButton(
              onPressed: _saveOutfitToFirebase,
              icon: const Icon(Icons.download),
              iconSize: 48,
              color: Colors.black,
              tooltip: '저장하기',
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),

      floatingActionButton: _generatedImageUrl != null
          ? null
          : null,
    );
  }
}