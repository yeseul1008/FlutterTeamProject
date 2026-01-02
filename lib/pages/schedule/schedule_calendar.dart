import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../widgets/common/weatherWidget.dart';

class UserScheduleCalendar extends StatefulWidget {
  const UserScheduleCalendar({super.key});

  @override
  State<UserScheduleCalendar> createState() => UserScheduleCalendarState();
}

class UserScheduleCalendarState extends State<UserScheduleCalendar> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final String? userId = FirebaseAuth.instance.currentUser?.uid;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  // 날짜별 calendar 문서 캐시 (없으면 null)
  final Map<DateTime, Map<String, dynamic>?> _calendarCache = {};

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  String _dateKey(DateTime d) {
    final day = _normalize(d);
    return '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic>? _getCalendar(DateTime day) => _calendarCache[_normalize(day)];

  String? _getThumb(DateTime day) => (_getCalendar(day)?['imageURL'] as String?);

  bool _isPast(DateTime day) {
    final today = _normalize(DateTime.now());
    return _normalize(day).isBefore(today);
  }

  @override
  void initState() {
    super.initState();
    _loadMonthCalendars(_focusedDay);
    _loadCalendarForDay(_selectedDay);
  }

  Future<void> _loadCalendarForDay(DateTime day) async {
    if (userId == null) return;

    final key = _normalize(day);
    if (_calendarCache.containsKey(key)) return;

    final docId = _dateKey(day);
    final doc = await fs.collection('users').doc(userId).collection('calendar').doc(docId).get();

    if (!mounted) return;
    setState(() {
      _calendarCache[key] = doc.exists ? (doc.data() ?? {}) : null;
    });
  }

  Future<void> _loadMonthCalendars(DateTime anyDayInMonth) async {
    if (userId == null) return;

    final monthStart = DateTime(anyDayInMonth.year, anyDayInMonth.month, 1);
    final monthEnd = DateTime(anyDayInMonth.year, anyDayInMonth.month + 1, 1);

    final snap = await fs
        .collection('users')
        .doc(userId)
        .collection('calendar')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .where('date', isLessThan: Timestamp.fromDate(monthEnd))
        .get();

    if (!mounted) return;

    setState(() {
      for (final d in snap.docs) {
        final data = d.data();
        final ts = data['date'];
        if (ts is! Timestamp) continue;

        final day = _normalize(ts.toDate());
        _calendarCache[day] = data; // 있으면 data
      }
    });
  }

  String _safeText(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? '없음' : s;
  }

  void _showTempSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 900)),
    );
  }

  Widget _infoText({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  // ======================================================
  // ✅ 룩북 옷 리스트 모달
  // calendar.lookbookId -> lookbooks.clothesIds -> users/{uid}/wardrobe/{id}.productName
  // ======================================================
  Future<List<String>> _loadClothesNamesForLookbook(String lookbookId) async {
    if (userId == null) return [];

    final lbDoc = await fs.collection('lookbooks').doc(lookbookId).get();
    final lb = lbDoc.data();
    final raw = (lb?['clothesIds'] as List<dynamic>? ?? []);
    final clothesIds = raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();

    if (clothesIds.isEmpty) return [];

    final names = await Future.wait<String>(clothesIds.map((cid) async {
      final wDoc = await fs
          .collection('users')
          .doc(userId)
          .collection('wardrobe')
          .doc(cid)
          .get();

      final w = wDoc.data();
      final n = (w?['productName'] as String?)?.trim();

      // productName이 비어있거나 null이면 대체
      return (n != null && n.isNotEmpty) ? n : '이름 없음';
    }));

    return names;
  }

  void _openClothesInfoModal() {
    final cal = _getCalendar(_selectedDay);

    if (userId == null) {
      _showTempSnack('로그인이 필요합니다.');
      return;
    }
    if (cal == null) {
      _showTempSnack('등록된 코디가 없습니다.');
      return;
    }

    final lookbookId = (cal['lookbookId'] ?? '').toString().trim();
    if (lookbookId.isEmpty) {
      _showTempSnack('룩북 정보가 없습니다.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '코디에 등록된 옷',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<String>>(
                  future: _loadClothesNamesForLookbook(lookbookId),
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snap.hasError) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('불러오기 실패', style: TextStyle(color: Colors.black54)),
                      );
                    }

                    final items = snap.data ?? [];
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('등록된 옷 정보가 없습니다.', style: TextStyle(color: Colors.black54)),
                      );
                    }

                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 1.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Colors.black12),
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Text(
                            items[i],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cal = _getCalendar(_selectedDay);
    final selectedThumb = _getThumb(_selectedDay);

    final hasSchedule = cal != null; // ✅ 문서 존재 여부
    final btnText = hasSchedule ? '일정 수정' : '일정 추가';

    // ✅ 목적지/일정(없으면 '없음')
    final destinationText = _safeText(cal?['destinationName']);
    final planText = _safeText(cal?['planText']);

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SizedBox(
        height: 68 + MediaQuery.of(context).padding.bottom,
        child: BottomAppBar(
          color: Colors.white,
          elevation: 0,
          shape: const CircularNotchedRectangle(),
          notchMargin: 10,
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
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

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () async {
                      setState(() {
                        _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                      });
                      await _loadMonthCalendars(_focusedDay);
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
                    onPressed: () async {
                      setState(() {
                        _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                      });
                      await _loadMonthCalendars(_focusedDay);
                    },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

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
                  await _loadCalendarForDay(selectedDay);
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

            const SizedBox(height: 6),

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
                        if (!hasSchedule) {
                          context.go('/AddSchedule', extra: {
                            'mode': 'create',
                            'selectedDate': _normalize(_selectedDay),
                          });
                        } else {
                          final scheduleId = (cal?['scheduleId'] ?? '').toString();
                          final destinationName = (cal?['destinationName'] ?? '').toString();
                          final planText2 = (cal?['planText'] ?? '').toString();
                          final imageURL = (cal?['imageURL'] ?? '').toString();
                          final dest = cal?['destination'];

                          double lat = 37.5665;
                          double lon = 126.9780;
                          if (dest is GeoPoint) {
                            lat = dest.latitude;
                            lon = dest.longitude;
                          }

                          context.go('/AddSchedule', extra: {
                            'mode': 'edit',
                            'selectedDate': _normalize(_selectedDay),
                            'scheduleId': scheduleId,
                            'destinationName': destinationName,
                            'planText': planText2,
                            'previewImageUrl': imageURL,
                            'lat': lat,
                            'lon': lon,
                          });
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

            // ✅ 목적지 / 일정 표시
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(child: _infoText(label: '목적지', value: destinationText)),
                  Expanded(child: _infoText(label: '일정', value: planText)),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    color: Colors.white,
                  ),
                  child: (selectedThumb == null || selectedThumb.isEmpty)
                      ? const SizedBox.expand(
                    child: Center(
                      child: Text(
                        '등록된 코디가 없습니다',
                        style: TextStyle(color: Colors.black38),
                      ),
                    ),
                  )
                      : Stack(
                    children: [
                      Positioned.fill(
                        child: Image.network(
                          selectedThumb,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.image_not_supported),
                          ),
                        ),
                      ),

                      // ✅ 인포 버튼(모달)
                      Positioned(
                        left: 10,
                        top: 10,
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: Material(
                            color: const Color(0xFFE5E7EB),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _openClothesInfoModal,
                              child: const Icon(
                                Icons.info_outline,
                                size: 18,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
    final Color todayRing = const Color(0xFFE11D70);
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
          if (thumb != null && thumb.isNotEmpty)
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
                shadows: (thumb != null && thumb.isNotEmpty)
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
