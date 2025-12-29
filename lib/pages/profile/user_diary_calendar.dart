import 'package:firebase_auth/firebase_auth.dart';
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
      body: Column(
        children: [
          SizedBox(height: 20),
          TableCalendar(
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            daysOfWeekHeight: 30,
            rowHeight: 90,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            headerStyle: HeaderStyle(
              titleTextStyle: TextStyle(
                fontSize: 24,  // Change size
                fontWeight: FontWeight.bold,  // Make it bold
                color: Colors.black,  // Change color
                // fontFamily: 'YourFont',  // Uncomment to use custom font
              ),
              formatButtonVisible: false,  // Hide format button
              titleCentered: true,  // Center the title
            ),
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: Color(0xFFCAD83B).withOpacity(0.5),
                shape: BoxShape.rectangle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.grey[400],
                shape: BoxShape.rectangle,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final imageUrl = _getOutfitImage(day);

                return Container(
                  margin: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSameDay(day, _selectedDay)
                          ? Color(0xFFCAD83B)
                          : Colors.transparent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: imageUrl != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[300],
                                child: Icon(Icons.image, size: 16),
                              );
                            },
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
          ),
          SizedBox(height: 20),
          SizedBox(
            width: 180,
            height: 50,
            child: ElevatedButton(
              onPressed: () async {
                if (_selectedDay == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('날짜를 먼저 선택해주세요')),
                  );
                  return;
                }

                Map<String, dynamic>? calendarEntry = await _getCalendarEntry(_selectedDay!);

                if (calendarEntry == null) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('알림'),
                      content: Text('캘린더에서 먼저 룩북을 등록해주세요'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('확인'),
                        ),
                      ],
                    ),
                  );
                } else {
                  context.go('/userDiaryAdd', extra: {
                    'lookbookId': calendarEntry['lookbookId'],
                    'date': calendarEntry['date'],
                    'selectedDay': _selectedDay,
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFCAD83B),
                foregroundColor: Colors.black,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: const BorderSide(color: Colors.black),
                ),
              ),
              child: const Text(
                'Write an entry',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
