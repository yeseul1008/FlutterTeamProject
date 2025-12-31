import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../widgets/common/weatherWidget.dart';
import '../../service/kakao/kakao_models.dart';
import '../../firebase/firestore_service.dart';

class UserScheduleAdd extends StatefulWidget {
  const UserScheduleAdd({super.key});

  @override
  State<UserScheduleAdd> createState() => _UserScheduleAddState();
}

class _UserScheduleAddState extends State<UserScheduleAdd> {
  static const String _openWeatherApiKey = '5ebe456d15b6fd5e52fbf09d1ab110ae';

  final FirestoreService _firestoreService = FirestoreService();

  // 목적지(좌표) 상태값: 기본 서울
  String? _placeName;
  double _lat = 37.5665;
  double _lon = 126.9780;

  // 일정 텍스트
  String? _scheduleText;

  // TODO: 캘린더에서 선택한 날짜를 이 페이지로 넘겨서 여기에 넣으세요.
  final DateTime _selectedDate = DateTime.now();

  bool _isSaving = false;

  Future<void> _onPickPlace() async {
    final KakaoPlace? picked = await context.push<KakaoPlace>('/placeSearch');
    if (picked == null) return;

    setState(() {
      _placeName = picked.name;
      _lat = picked.lat;
      _lon = picked.lon;
    });
  }

  void _onAddSchedule() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('일정 입력 UI 연결 필요')),
    );
  }

  // ✅ 옷장 -> 조합 -> (캔버스 PNG 업로드) -> 룩북 생성 -> schedules + calendar 저장
  Future<void> _onPickWardrobeAndRegister() async {
    if (_isSaving) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    try {
      setState(() => _isSaving = true);

      // 1) 옷장 이동 (ScheduleWardrobe가 pop(result)로 돌아오게 되어있어야 함)
      final wardrobeResult =
      await context.push<Map<String, dynamic>>('/scheduleWardrobe');
      if (wardrobeResult == null) return;

      final List<String> clothesIds =
      (wardrobeResult['clothesIds'] as List<dynamic>? ?? []).cast<String>();

      final Map<String, dynamic> imageUrlsRaw =
      (wardrobeResult['imageUrls'] as Map<String, dynamic>? ?? {});
      final Map<String, String> imageUrls =
      imageUrlsRaw.map((k, v) => MapEntry(k, v.toString()));

      if (clothesIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('선택된 옷이 없습니다.')),
        );
        return;
      }

      // 2) 조합하기 이동
      final combineResult = await context.push<Map<String, dynamic>>(
        '/scheduleCombine',
        extra: {
          'clothesIds': clothesIds,
          'imageUrls': imageUrls,
        },
      );

      if (combineResult == null) return;
      if (combineResult['action'] != 'registerToSchedule') return;

      final List<String> finalClothesIds =
      (combineResult['clothesIds'] as List<dynamic>? ?? []).cast<String>();

      if (finalClothesIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('캔버스에 남은 옷이 없습니다.')),
        );
        return;
      }

      // 3) ✅ 캔버스 PNG bytes (있으면 업로드해서 resultImageUrl 만들기)
      String resultImageUrl = '';
      final Uint8List? canvasPngBytes = combineResult['canvasPngBytes'] as Uint8List?;
      if (canvasPngBytes != null && canvasPngBytes.isNotEmpty) {
        resultImageUrl = await _firestoreService.uploadLookbookCanvasPng(
          userId: user.uid,
          pngBytes: canvasPngBytes,
        );
      }

      // 4) 룩북 생성 (resultImageUrl 채워짐)
      final String lookbookId = await _firestoreService.createLookbookWithFlag(
        userId: user.uid,
        alias: (_scheduleText != null && _scheduleText!.trim().isNotEmpty)
            ? _scheduleText!.trim()
            : '일정 코디',
        resultImageUrl: resultImageUrl, // ✅ 캔버스 이미지 URL
        clothesIds: finalClothesIds,
        inLookbook: true,
        publishToCommunity: false,
      );

      // 5) schedules + calendar 저장
      await _firestoreService.createScheduleAndCalendar(
        userId: user.uid,
        date: _selectedDate,
        weather: 'unknown', // TODO: 실제 날씨 값으로 교체
        destinationName: _placeName ?? '없음',
        lat: _lat,
        lon: _lon,
        planText: _scheduleText ?? '',
        lookbookId: lookbookId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일정에 등록되었습니다.')),
      );

      // 필요하면 캘린더로 이동
      // context.go('/userScheduleCalendar');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _infoCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 1),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 4),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _pillButton({required String text, required VoidCallback onTap}) {
    const lime = Color(0xFFCAD83B);
    return SizedBox(
      height: 30,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: lime,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.black),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
        ),
      ),
    );
  }

  Widget _squareActionButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    const cardPurple = Color(0xFFC9B7FF);

    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: cardPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Colors.black),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _isSaving ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: Colors.black),
                const SizedBox(height: 12),
                Text(
                  _isSaving ? '저장 중...' : text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _labelValueRow({
    required String label,
    required String value,
    required VoidCallback onAdd,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        _pillButton(text: '추가', onTap: onAdd),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.w800);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: [
              const SizedBox(height: 10),

              Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/userScheduleCalendar'),
                    icon: const Icon(Icons.arrow_back_ios_new),
                  ),
                  const Expanded(
                    child: Center(child: Text('일정 추가하기', style: titleStyle)),
                  ),
                  const SizedBox(width: 48),
                ],
              ),

              const SizedBox(height: 18),

              _infoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '2017. 7.19 wed',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),

                    WeatherWidget(
                      date: _selectedDate,
                      lat: _lat,
                      lon: _lon,
                      apiKey: _openWeatherApiKey,
                    ),

                    const SizedBox(height: 14),

                    _labelValueRow(
                      label: '목적지',
                      value: _placeName == null ? '없음' : _placeName!,
                      onAdd: _onPickPlace,
                    ),

                    const SizedBox(height: 12),

                    _labelValueRow(
                      label: '일정',
                      value: _scheduleText == null ? '없음' : _scheduleText!,
                      onAdd: _onAddSchedule,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              Row(
                children: [
                  Expanded(
                    child: _squareActionButton(
                      icon: Icons.checkroom_outlined,
                      text: '나의 옷\n가져오기',
                      onTap: _onPickWardrobeAndRegister,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _squareActionButton(
                      icon: Icons.menu_book_outlined,
                      text: '나의 룩북\n가져오기',
                      onTap: () => context.go('/scheduleLookbook'),
                    ),
                  ),
                ],
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
