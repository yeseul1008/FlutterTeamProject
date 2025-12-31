import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../widgets/common/weatherWidget.dart';

class UserScheduleCalendar extends StatefulWidget {
  const UserScheduleCalendar({super.key});

  @override
  State<UserScheduleCalendar> createState() => _UserScheduleCalendarState();
}

class _UserScheduleCalendarState extends State<UserScheduleCalendar> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final String? userId = FirebaseAuth.instance.currentUser?.uid;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  // ✅ 날짜별 썸네일 캐시 (캘린더 셀/프리뷰 공용)
  final Map<DateTime, String?> _thumbCache = {};

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  String? _getThumb(DateTime day) => _thumbCache[_normalize(day)];

  bool _isPast(DateTime day) {
    final today = _normalize(DateTime.now());
    return _normalize(day).isBefore(today);
  }

  @override
  void initState() {
    super.initState();
    _loadThumbForDay(_selectedDay); // 첫 진입 시 오늘 프리뷰도 로드
  }

  Future<void> _loadThumbForDay(DateTime day) async {
    if (userId == null) return;

    final key = _normalize(day);

    // 이미 캐시가 있으면 또 조회 안함(원하면 제거 가능)
    if (_thumbCache.containsKey(key)) return;

    final url = await _fetchResultImageUrlForDay(day);
    if (!mounted) return;

    setState(() {
      _thumbCache[key] = url; // url이 null이면 "등록 없음"으로 캐싱됨
    });
  }

  Future<String?> _fetchResultImageUrlForDay(DateTime day) async {
    if (userId == null) return null;

    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    // 1) schedules에서 해당 날짜 일정 1개 찾기
    final scheduleSnap = await fs
        .collection('users')
        .doc(userId)
        .collection('schedules')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .limit(1)
        .get();

    if (scheduleSnap.docs.isEmpty) return null;

    final scheduleData = scheduleSnap.docs.first.data();
    final lookbookId = (scheduleData['lookbookId'] ?? '').toString();
    if (lookbookId.isEmpty) return null;

    // 2) lookbooks에서 resultImageUrl 가져오기
    final lookbookDoc = await fs.collection('lookbooks').doc(lookbookId).get();
    if (!lookbookDoc.exists) return null;

    final lookbookData = lookbookDoc.data() as Map<String, dynamic>?;
    final resultImageUrl = (lookbookData?['resultImageUrl'] ?? '').toString();

    if (resultImageUrl.trim().isEmpty) return null;
    return resultImageUrl;
  }

  @override
  Widget build(BuildContext context) {
    final selectedThumb = _getThumb(_selectedDay);

    const double bottomBarH = 68;
    final double safeBottom = MediaQuery.of(context).padding.bottom;

    // 룩북(코디) 존재 여부
    final bool hasLookbook = selectedThumb != null;

    // 목적지 / 목적 (아직 미구현 → 임시 false)
    final bool hasDestination = false; // TODO
    final bool hasPurpose = false; // TODO

    final bool needAdd = !(hasLookbook && hasDestination && hasPurpose);
    final String btnText = needAdd ? '일정 추가' : '일정 수정';

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // 하단 네비
      bottomNavigationBar: SizedBox(
        height: bottomBarH + safeBottom,
        child: BottomAppBar(
          color: Colors.white,
          elevation: 0,
          shape: const CircularNotchedRectangle(),
          notchMargin: 10,
          child: Padding(
            padding: EdgeInsets.only(bottom: safeBottom),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(label: 'closet', icon: Icons.checkroom_outlined, onTap: () {}),
                _NavItem(label: 'calendar', icon: Icons.calendar_month_outlined, onTap: () {}),
                const SizedBox(width: 70),
                _NavItem(label: 'diary', icon: Icons.menu_book_outlined, onTap: () {}),
                _NavItem(label: 'community', icon: Icons.groups_outlined, onTap: () {}),
              ],
            ),
          ),
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 6),

            // 상단 월 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                      });
                    },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Center(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                          children: [
                            TextSpan(text: _monthName(_focusedDay.month)),
                            TextSpan(
                              text: ' ${_focusedDay.year}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                      });
                    },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // 요일
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Dow('Sun'),
                  _Dow('Mon'),
                  _Dow('Tue'),
                  _Dow('Wed'),
                  _Dow('Thu'),
                  _Dow('Fri'),
                  _Dow('Sat'),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 캘린더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TableCalendar(
                headerVisible: false,
                daysOfWeekVisible: false,
                firstDay: DateTime.utc(2010, 1, 1),
                lastDay: DateTime.utc(2035, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                rowHeight: 52,
                onDaySelected: (selectedDay, focusedDay) async {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  // ✅ 선택한 날짜의 프리뷰 이미지 로드
                  await _loadThumbForDay(selectedDay);
                },
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, _) => _buildDayCell(day, isSelected: false),
                  selectedBuilder: (context, day, _) => _buildDayCell(day, isSelected: true),
                  todayBuilder: (context, day, _) => _buildDayCell(
                    day,
                    isSelected: isSameDay(day, _selectedDay),
                    forceToday: true,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // 날짜 텍스트
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                '${_monthName(_selectedDay.month)} ${_selectedDay.day}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),

            const SizedBox(height: 6),

            // 날씨(왼쪽) + 일정추가 버튼(오른쪽)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: WeatherWidget(
                        date: _selectedDay,
                        lat: 37.5665,
                        lon: 126.9780,
                        apiKey: '5ebe456d15b6fd5e52fbf09d1ab110ae',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 34,
                    child: ElevatedButton(
                      onPressed: () {
                        if (btnText == '일정 추가') {
                          context.go('/AddSchedule');
                        } else {
                          context.go('/EditSchedule');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFFCAD83B),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: Colors.black),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: Text(
                        btnText,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ✅ 프리뷰 영역: 선택한 날짜의 lookbook.resultImageUrl 표시
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    color: Colors.white,
                  ),
                  child: (selectedThumb == null)
                      ? const SizedBox.expand(
                    child: Center(
                      child: Text(
                        '등록된 코디가 없습니다',
                        style: TextStyle(color: Colors.black38),
                      ),
                    ),
                  )
                      : Image.network(
                    selectedThumb,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.image_not_supported),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCell(
      DateTime day, {
        required bool isSelected,
        bool forceToday = false,
      }) {
    final thumb = _getThumb(day);
    final past = _isPast(day);

    final Color pastBg = const Color(0xFFF3F4F6);
    final Color todayRing = const Color(0xFFCBD5E1);
    final Color selectedRing = const Color(0xFFA88AF7);

    final textColor = past ? const Color(0xFF6B7280) : Colors.black87;
    final imgOpacity = past ? 0.55 : 1.0;

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: past ? pastBg : Colors.transparent,
        border: Border.all(
          color: isSelected ? selectedRing : (forceToday ? todayRing : Colors.transparent),
          width: isSelected ? 2 : (forceToday ? 1.5 : 0),
        ),
      ),
      child: Stack(
        children: [
          if (thumb != null)
            Positioned.fill(
              child: Opacity(
                opacity: imgOpacity,
                child: Image.network(
                  thumb,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.grey[200]),
                ),
              ),
            ),
          Positioned(
            top: 4,
            left: 4,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: textColor,
                shadows: thumb != null
                    ? const [
                  Shadow(
                    blurRadius: 8,
                    color: Colors.white,
                    offset: Offset(0, 0),
                  )
                ]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int m) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[m - 1];
  }
}

class _Dow extends StatelessWidget {
  final String text;
  const _Dow(this.text);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: Colors.black54),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: Colors.black87),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
