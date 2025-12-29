import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  // Sample data - TODO: Replace with Firebase
  Map<DateTime, String> _outfitImages = {
    DateTime(2025, 12, 25): 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=400',
    DateTime(2025, 12, 26): 'https://images.unsplash.com/photo-1490481651871-ab68de25d43d?w=400',
    DateTime(2025, 12, 24): 'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=400',
    DateTime(2025, 12, 23): 'https://images.unsplash.com/photo-1525507119028-ed4c629a60a3?w=400',
    DateTime(2025, 12, 27): 'https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=400',
  };

  String? _getOutfitImage(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _outfitImages[normalizedDay];
  }

  // Function to check if there is a lookbook registered on a specific date

  Future<bool> _hasCalendarEntry(DateTime date) async {
    try {
      // You need to specify which user's calendar to check
      String userId = 'tHuRzoBNhPhONwrBeUME'; // Use the actual user ID

      // Create start and end of the day
      final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      print('Checking calendar for user: $userId');
      print('Date range: $startOfDay to $endOfDay');

      // Access the subcollection: users/{userId}/calendar
      final querySnapshot = await fs
          .collection('users')
          .doc(userId)
          .collection('calendar')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      print('Query found ${querySnapshot.docs.length} documents');

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking calendar entry: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Container(
          //   width: double.infinity,
          //   height: 180,
          //   decoration: BoxDecoration(
          //     color: Colors.black,
          //   ),
          //   child: Text(
          //       "my calendar",
          //       style: TextStyle(color: Colors.white),
          //   ),
          // ),
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

              // Show full image in dialog when clicked
              // final imageUrl = _getOutfitImage(selectedDay);
              // if (imageUrl != null) {
              //   _showOutfitDialog(selectedDay, imageUrl);
              // }
            },
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: Color(0xFFCAD83B).withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.grey[400],
                shape: BoxShape.circle,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              // Custom builder to show images on dates
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
                      // Date number
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Outfit thumbnail
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
                            : SizedBox.shrink(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: 180,
            height: 50,
            child: ElevatedButton(
                onPressed: () async {
                  if (_selectedDay == null) {
                    // No date selected
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('날짜를 먼저 선택해주세요')),
                    );
                    return;
                  }

                  // Check if calendar entry exists for selected date
                  bool hasEntry = await _hasCalendarEntry(_selectedDay!);

                  if (!hasEntry) {
                    // Show alert - no lookbook registered yet
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
                    // Has entry - go to diary writing page
                    context.go('/userLookbookAdd'); // TODO: Update with your actual diary writing route
                  }
                },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFCAD83B),
                foregroundColor: Colors.black,
                elevation: 0,
                padding: EdgeInsets.zero, // 높이 정확히 맞춤
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: const BorderSide(color: Colors.black),
                ),
              ),
              child: const Text(
                '일기 추가',
                style: TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOutfitDialog(DateTime date, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Date at the top
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '${date.month}월 ${date.day}일',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Image
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 300,
                      color: Colors.grey[300],
                      child: Icon(Icons.image_not_supported, size: 80),
                    );
                  },
                ),
                // Buttons
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Edit outfit
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.edit),
                        label: Text('수정'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Delete outfit
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.delete),
                        label: Text('삭제'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // 닫기 버튼
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}