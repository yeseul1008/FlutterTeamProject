import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  // GlobalKeys for tutorial targets
  final GlobalKey _monthNavigationKey = GlobalKey();
  final GlobalKey _calendarKey = GlobalKey();
  final GlobalKey _writeEntryKey = GlobalKey();

  TutorialCoachMark? tutorialCoachMark;

  // Store lookbooks by date
  Map<DateTime, Map<String, dynamic>> _lookbooksByDate = {};

  @override
  void initState() {
    super.initState();
    _loadLookbooks().then((_) {
      _checkAndShowTutorial();
    });
  }

  // Check if this is the user's first time on calendar page
  Future<void> _checkAndShowTutorial() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // bool hasSeenCalendarTutorial = prefs.getBool('hasSeenCalendarTutorial') ?? false;
    bool hasSeenCalendarTutorial = false;

    if (!hasSeenCalendarTutorial) {
      Future.delayed(Duration(milliseconds: 800), () {
        _showTutorial();
        prefs.setBool('hasSeenCalendarTutorial', true);
      });
    }
  }

  void _createTutorial() {
    tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Colors.black,
      textSkip: "Skip",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        print("Calendar tutorial finished");
      },
      onClickTarget: (target) {
        print('Clicked on ${target.identify}');
      },
      onSkip: () {
        print("Calendar tutorial skipped");
        return true;
      },
    );
  }

  List<TargetFocus> _createTargets() {
    List<TargetFocus> targets = [];

    // Target 1: Month Navigation
    targets.add(
      TargetFocus(
        identify: "month-navigation",
        keyTarget: _monthNavigationKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 8,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.calendar_month, color: Color(0xFFCAD83B), size: 40),
                    SizedBox(height: 10),
                    Text(
                      "Month Navigation",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "좌우 화살표로 다른 달을 탐색할 수 있습니다",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );

    // Target 2: Calendar Grid
    targets.add(
      TargetFocus(
        identify: "calendar-grid",
        keyTarget: _calendarKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 8,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.view_module, color: Color(0xFFCAD83B), size: 40),
                    SizedBox(height: 10),
                    Text(
                      "Calendar View",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "캘린더에서 룩북이 등록된 날짜를 확인할 수 있습니다. 날짜를 탭해서 선택하세요",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );

    // Target 3: Write Entry Button
    targets.add(
      TargetFocus(
        identify: "write-entry",
        keyTarget: _writeEntryKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 30,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.edit, color: Color(0xFFCAD83B), size: 40),
                    SizedBox(height: 10),
                    Text(
                      "Write Entry",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "날짜를 선택한 후 이 버튼을 눌러 다이어리를 작성하세요",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );

    return targets;
  }

  void _showTutorial() {
    _createTutorial();
    tutorialCoachMark?.show(context: context);
  }

  Future<void> _loadLookbooks() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      print('User not logged in');
      return;
    }

    try {
      final calendarSnapshot = await fs
          .collection('users')
          .doc(uid)
          .collection('calendar')
          .get();

      print('Found ${calendarSnapshot.docs.length} calendar entries');

      Map<DateTime, Map<String, dynamic>> lookbooksMap = {};

      for (var doc in calendarSnapshot.docs) {
        final data = doc.data();
        final dateTimestamp = data['date'] as Timestamp?;

        if (dateTimestamp != null) {
          final date = dateTimestamp.toDate();
          final normalizedDate = DateTime(date.year, date.month, date.day);

          lookbooksMap[normalizedDate] = {
            'imageUrl': data['imageURL'],
            'lookbookId': data['lookbookId'],
            'date': dateTimestamp,
            'createdAt': data['createdAt'],
          };

          print('Added lookbook for date: $normalizedDate, imageUrl: ${data['imageUrl']}');
        }
      }

      if (!mounted) return;
      setState(() {
        _lookbooksByDate = lookbooksMap;
      });

      print('Loaded ${_lookbooksByDate.length} lookbooks');
    } catch (e) {
      print('Error loading lookbooks: $e');
    }
  }

  String? _getOutfitImage(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _lookbooksByDate[normalizedDay]?['imageUrl'];
  }

  Future<Map<String, dynamic>?> _getCalendarEntry(DateTime date) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) {
        print('User not logged in');
        return null;
      }

      final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final querySnapshot = await fs
          .collection('users')
          .doc(userId)
          .collection('calendar')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      print('Error getting calendar entry: $e');
      return null;
    }
  }

  String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SizedBox(height: 60),

          // Custom Header
          Padding(
            key: _monthNavigationKey,  // ADD KEY
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
          SizedBox(height: 20),

          Container(
            key: _calendarKey,  // ADD KEY
            child: TableCalendar(
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
              headerVisible: false,
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.rectangle,
                    border: Border.all(color: Colors.purple)
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                todayBuilder: (context, day, focusedDay) {
                  final imageUrl = _getOutfitImage(day);

                  return Container(
                    margin: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Color(0xFFA88AF7), width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${day.day}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: imageUrl != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          )
                              : const SizedBox.expand(),
                        ),
                      ],
                    ),
                  );
                },

                selectedBuilder: (context, day, focusedDay) {
                  final imageUrl = _getOutfitImage(day);

                  return Container(
                    margin: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCAD83B), width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${day.day}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: imageUrl != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          )
                              : const SizedBox.expand(),
                        ),
                      ],
                    ),
                  );
                },

                defaultBuilder: (context, day, focusedDay) {
                  final imageUrl = _getOutfitImage(day);

                  return Container(
                    margin: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSameDay(day, _selectedDay)
                            ? const Color(0xFFCAD83B)
                            : isSameDay(day, DateTime.now())
                            ? Colors.grey
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
                          )
                              : SizedBox.expand(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            key: _writeEntryKey,  // ADD KEY
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
                      backgroundColor: Colors.white,
                      title: Text('알림', style: TextStyle(fontWeight: FontWeight.bold),),
                      content: Text('캘린더에서 먼저 룩북을 등록해주세요.'),
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('확인'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFCAD83B),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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