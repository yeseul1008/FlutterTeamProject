import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.black,
            ),
            child: Text(
                "my calendar",
                style: TextStyle(color: Colors.white),
            ),
          ),
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
              final imageUrl = _getOutfitImage(selectedDay);
              if (imageUrl != null) {
                _showOutfitDialog(selectedDay, imageUrl);
              }
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
              onPressed: () => context.go('/userLookbookAdd'),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text('${date.month}/${date.day} 코디'),
              backgroundColor: Color(0xFFCAD83B),
              leading: IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
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
      ),
    );
  }
}