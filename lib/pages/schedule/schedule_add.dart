import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/common/weatherWidget.dart';
import '../../service/kakao/kakao_models.dart'; //

class UserScheduleAdd extends StatefulWidget {
  const UserScheduleAdd({super.key});

  @override
  State<UserScheduleAdd> createState() => _UserScheduleAddState();
}

class _UserScheduleAddState extends State<UserScheduleAdd> {
  static const String _openWeatherApiKey = '5ebe456d15b6fd5e52fbf09d1ab110ae';

  final TextEditingController _scheduleController = TextEditingController();

  // 목적지(좌표) 상태값: 기본 서울
  String _placeName = '서울';
  double _lat = 37.5665;
  double _lon = 126.9780;

  @override
  void dispose() {
    _scheduleController.dispose();
    super.dispose();
  }

  void _onAddSchedule() {
    final text = _scheduleController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일정을 입력해주세요.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('일정이 입력되었습니다.')),
    );
  }

  // 목적지 검색 페이지 이동 -> 선택값 받아오기
  Future<void> _onPickPlace() async {
    final KakaoPlace? picked = await context.push<KakaoPlace>('/placeSearch');
    if (picked == null) return;

    setState(() {
      _placeName = picked.name;
      _lat = picked.lat;
      _lon = picked.lon;
    });
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFFA88AF7);
    const lime = Color(0xFFCAD83B);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),

            // 상단 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/userScheduleCalendar'),
                    icon: const Icon(Icons.arrow_back_ios_new),
                  ),
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: purple,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.black),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '일정 추가하기',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 날짜 + 목적지 추가 (날짜 그대로)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  const Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '2017. 7.19 wed',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 34,
                    child: OutlinedButton(
                      onPressed: _onPickPlace,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: Text(
                        '+ 목적지 추가 ($_placeName)',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 날씨(왼쪽) + 일정추가 버튼(오른쪽)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: WeatherWidget(
                        date: DateTime.now(), // TODO: 나중에 선택 날짜로 교체
                        lat: _lat,
                        lon: _lon,
                        apiKey: _openWeatherApiKey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 34,
                    child: OutlinedButton(
                      onPressed: _onAddSchedule,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text(
                        '일정 추가',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 일정 텍스트필드
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _scheduleController,
                  decoration: InputDecoration(
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Colors.black),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide:
                      const BorderSide(color: Colors.black, width: 1.2),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 22),

            // 내 옷장 불러오기
            SizedBox(
              width: 220,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  context.go('/scheduleWardrobe');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: lime,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                    side: const BorderSide(color: Colors.black),
                  ),
                ),
                child: const Text(
                  '내 옷장 불러오기',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 내 룩북 불러오기
            SizedBox(
              width: 220,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  // TODO
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: lime,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                    side: const BorderSide(color: Colors.black),
                  ),
                ),
                child: const Text(
                  '내 룩북 불러오기',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}
