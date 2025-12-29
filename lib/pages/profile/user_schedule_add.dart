import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UserScheduleAdd extends StatefulWidget {
  const UserScheduleAdd({super.key});

  @override
  State<UserScheduleAdd> createState() => _UserScheduleAddState();
}

class _UserScheduleAddState extends State<UserScheduleAdd> {
  final TextEditingController _scheduleController = TextEditingController();

  @override
  void dispose() {
    _scheduleController.dispose();
    super.dispose();
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

            // 상단 헤더(뒤로가기 + 타이틀)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/calendarPage'),
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
                  const SizedBox(width: 48), // 왼쪽 아이콘 균형 맞춤
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ✅ 날짜 + 날씨 (일단 UI 고정)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  const Text(
                    '2017. 7.19 wed',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 34,
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO: 목적지 추가(지도 API) - 지금은 패스
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: const Text(
                        '+ 목적지 추가',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  const Icon(Icons.cloud, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    '최저 18도/ 최고 25도',
                    style: TextStyle(fontSize: 12),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 34,
                    child: OutlinedButton(
                      onPressed: () {
                        // ✅ 일정 추가(텍스트 입력값 사용)
                        final text = _scheduleController.text.trim();
                        if (text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('일정을 입력해주세요.')),
                          );
                          return;
                        }

                        // TODO: 저장 로직(Firebase) 연결 예정
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('일정이 입력되었습니다.')),
                        );
                      },
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
                      borderSide: const BorderSide(color: Colors.black, width: 1.2),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 22),

            // ✅ 내 옷장 불러오기 버튼
            SizedBox(
              width: 220,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: 내 옷장 불러오기
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

            // ✅ 내 룩북 불러오기 버튼
            SizedBox(
              width: 220,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: 내 룩북 불러오기
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
