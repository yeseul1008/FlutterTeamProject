import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common/weatherWidget.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  // UI용 더미 썸네일
  final Map<DateTime, String> _outfitImages = {
    DateTime(2025, 12, 23):
    'https://images.unsplash.com/photo-1520975958225-5f61fdd7b13a?w=600',
    DateTime(2025, 12, 24):
    'https://images.unsplash.com/photo-1520975682031-a3d3ad9c0b3a?w=600',
    DateTime(2025, 12, 25):
    'https://images.unsplash.com/photo-1520975900602-1f81b190e0b8?w=600',
    DateTime(2025, 12, 26):
    'https://images.unsplash.com/photo-1520975910938-2dba43f8e812?w=600',
    DateTime(2025, 12, 27):
    'https://images.unsplash.com/photo-1520975923003-56a5d7a6d5d1?w=600',
  };

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);
  String? _getThumb(DateTime day) => _outfitImages[_normalize(day)];

  bool _isPast(DateTime day) {
    final today = _normalize(DateTime.now());
    return _normalize(day).isBefore(today);
  }

  @override
  Widget build(BuildContext context) {
    final selectedThumb = _getThumb(_selectedDay);

    const double bottomBarH = 68;
    final double safeBottom = MediaQuery.of(context).padding.bottom;

    final bool isPastSelected = _isPast(_selectedDay);
    final bool hasSchedule = selectedThumb != null; // 썸네일 있으면 일정 등록된 것으로 간주

    final String btnText =
    isPastSelected ? '일기 등록' : (hasSchedule ? '일정 수정' : '일정 추가');

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
                _NavItem(
                    label: 'closet',
                    icon: Icons.checkroom_outlined,
                    onTap: () {}),
                _NavItem(
                    label: 'calendar',
                    icon: Icons.calendar_month_outlined,
                    onTap: () {}),
                const SizedBox(width: 70),
                _NavItem(
                    label: 'diary',
                    icon: Icons.menu_book_outlined,
                    onTap: () {}),
                _NavItem(
                    label: 'community',
                    icon: Icons.groups_outlined,
                    onTap: () {}),
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
                        _focusedDay =
                            DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
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
                        _focusedDay =
                            DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
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
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, _) =>
                      _buildDayCell(day, isSelected: false),
                  selectedBuilder: (context, day, _) =>
                      _buildDayCell(day, isSelected: true),
                  todayBuilder: (context, day, _) => _buildDayCell(
                    day,
                    isSelected: isSameDay(day, _selectedDay),
                    forceToday: true,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // 스크롤 영역
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: Column(
                  children: [
                    Text(
                      '${_selectedDay.year} ${_monthName(_selectedDay.month)} ${_selectedDay.day}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // WeatherWidget (5일 예보 기반 버전)
                    // apiKey는 weatherWidget.dart에서 fallback 사용 중이면 여기선 생략 가능
                    // 권장: apiKey를 주입하세요.
                    WeatherWidget(
                      date: _selectedDay,
                      lat: 37.5665,
                      lon: 126.9780,
                      apiKey: '5ebe456d15b6fd5e52fbf09d1ab110ae',
                    ),

                    const SizedBox(height: 14),

                    // 프리뷰
                    Container(
                      width: double.infinity,
                      height: 320,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12),
                        color: Colors.white,
                      ),
                      child: (selectedThumb == null)
                          ? const Center(
                        child: Text(
                          '등록된 코디가 없습니다',
                          style: TextStyle(color: Colors.black38),
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
                  ],
                ),
              ),
            ),

            // ✅ 버튼: 스크롤 밖(한 화면에서 바로 보이게)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (btnText == '일정 추가') {
                      context.go('/AddSchedule');
                    } else if (btnText == '일정 수정') {
                      context.go('/EditSchedule');
                    } else {
                      // '일기 등록' 라우트는 아직 안 주셔서 여기서는 이동 안 합니다.
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFFCAD83B),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: const BorderSide(color: Colors.black),
                    ),
                  ),
                  child: Text(
                    btnText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
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
          color: isSelected
              ? selectedRing
              : (forceToday ? todayRing : Colors.transparent),
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
                  errorBuilder: (_, __, ___) =>
                      Container(color: Colors.grey[200]),
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
