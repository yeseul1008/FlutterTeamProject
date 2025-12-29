import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'location_picker_map.dart';

class UserDiaryAdd extends StatefulWidget {
  const UserDiaryAdd({super.key});

  @override
  State<UserDiaryAdd> createState() => _UserDiaryAddState();
}

class _UserDiaryAddState extends State<UserDiaryAdd> {
  String? lookbookId;
  Timestamp? date;
  DateTime? selectedDay;
  String? imageUrl;
  String? locationText;
  GeoPoint? selectedLocation;
  bool isDiaryAlreadyExists = false;  // ADD THIS

  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final TextEditingController _commentController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final data = GoRouterState.of(context).extra as Map<String, dynamic>?;

    if (data != null) {
      lookbookId = data['lookbookId'];
      date = data['date'];
      selectedDay = data['selectedDay'];

      print('Received lookbookId: $lookbookId');
      print('Received date: $date');
      print('Received selectedDay: $selectedDay');

      _loadImage();
      _checkIfDiaryExists();  // ADD THIS
    }
  }

  // ADD THIS FUNCTION
  Future<void> _checkIfDiaryExists() async {
    if (selectedDay == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final startOfDay = DateTime(selectedDay!.year, selectedDay!.month, selectedDay!.day, 0, 0, 0);
      final endOfDay = DateTime(selectedDay!.year, selectedDay!.month, selectedDay!.day, 23, 59, 59);

      final calendarQuery = await fs
          .collection('users')
          .doc(uid)
          .collection('calendar')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      if (calendarQuery.docs.isNotEmpty) {
        final calendarData = calendarQuery.docs.first.data();
        final inDiary = calendarData['inDiary'] ?? false;

        if (inDiary == true) {
          setState(() {
            isDiaryAlreadyExists = true;
          });

          // Show dialog warning
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('이미 작성된 일기'),
                  ],
                ),
                content: Text('이 룩북에 대한 일기를 이미 작성하셨습니다.\n수정하시겠습니까?'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('/calendarPage');
                    },
                    child: Text('취소'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        isDiaryAlreadyExists = false;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFCAD83B),
                      foregroundColor: Colors.black,
                    ),
                    child: Text('수정하기'),
                  ),
                ],
              ),
            );
          });
        }
      }
    } catch (e) {
      print('Error checking diary existence: $e');
    }
  }

  Future<void> _loadImage() async {
    if (selectedDay == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final startOfDay = DateTime(selectedDay!.year, selectedDay!.month, selectedDay!.day, 0, 0, 0);
      final endOfDay = DateTime(selectedDay!.year, selectedDay!.month, selectedDay!.day, 23, 59, 59);

      final querySnapshot = await fs
          .collection('users')
          .doc(uid)
          .collection('calendar')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final calendarData = querySnapshot.docs.first.data();
        setState(() {
          imageUrl = calendarData['imageUrl'];
        });
        print('Loaded image URL: $imageUrl');
      }
    } catch (e) {
      print('Error loading image: $e');
    }
  }

  Future<void> _saveDiaryEntry() async {
    print('=== SAVE BUTTON CLICKED ===');

    final comment = _commentController.text.trim();
    print('Comment: "$comment"');
    print('selectedLocation: $selectedLocation');
    print('locationText: $locationText');
    print('lookbookId: $lookbookId');
    print('date: $date');

    if (comment.isEmpty) {
      print('Comment is empty!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('코멘트를 입력해주세요'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (selectedLocation == null || locationText == null) {
      print('Location is null!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('위치를 선택해주세요'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    print('User ID: $uid');

    if (uid == null) {
      print('User not logged in!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인이 필요합니다'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      print('Attempting to save to Firestore...');

      // Save diary to Firestore
      await fs
          .collection('users')
          .doc(uid)
          .collection('diaries')
          .add({
        'lookbookId': lookbookId,
        'date': date,
        'location': selectedLocation,
        'locationText': locationText,
        'comment': comment,
        'createdAt': Timestamp.now(),
      });

      // UPDATE CALENDAR ENTRY - Mark as having a diary
      if (selectedDay != null) {
        final startOfDay = DateTime(selectedDay!.year, selectedDay!.month, selectedDay!.day, 0, 0, 0);
        final endOfDay = DateTime(selectedDay!.year, selectedDay!.month, selectedDay!.day, 23, 59, 59);

        final calendarQuery = await fs
            .collection('users')
            .doc(uid)
            .collection('calendar')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
            .limit(1)
            .get();

        if (calendarQuery.docs.isNotEmpty) {
          await calendarQuery.docs.first.reference.update({'inDiary': true});
          print('Calendar entry marked as having diary');
        }
      }

      print('Successfully saved!');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('일기가 저장되었습니다!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      context.go('/userDiaryCards');

    } catch (e) {
      print('ERROR saving diary: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 실패: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLocationPicker() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          height: 500,
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '위치 선택',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Expanded(
                child: LocationPickerMap(
                  onLocationSelected: (location, name) {
                    setState(() {
                      selectedLocation = location;
                      locationText = name;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '날짜 없음';
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('Write an entry'),
            // Show icon if diary already exists
            if (isDiaryAlreadyExists) ...[
              SizedBox(width: 8),
              Icon(
                Icons.edit_note,
                color: Colors.orange,
                size: 24,
              ),
            ],
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.go('/calendarPage'),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Warning banner if diary exists
              if (isDiaryAlreadyExists)
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '이 룩북에 대한 일기가 이미 작성되어 있습니다',
                          style: TextStyle(color: Colors.orange.shade900),
                        ),
                      ),
                    ],
                  ),
                ),

              // Image section
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageUrl != null
                      ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 80,
                          color: Colors.grey[600],
                        ),
                      );
                    },
                  )
                      : Center(
                    child: Icon(
                      Icons.image,
                      size: 80,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Date and Location button in one row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Date section with calendar icon
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 24),
                      SizedBox(width: 8),
                      Text(
                        _formatDate(selectedDay),
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),

                  // Location button
                  SizedBox(
                    width: 150,
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: _showLocationPicker,
                      icon: Icon(Icons.location_pin, size: 18),
                      label: Text(
                        locationText ?? '위치추가',
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: BorderSide(color: Colors.grey[400]!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Comment text field
              TextField(
                controller: _commentController,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: '오늘의 코디에 대해 기록해보세요...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.all(16),
                ),
              ),

              SizedBox(height: 20),

              // Save button aligned to the right
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 120,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveDiaryEntry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFCAD83B),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: const BorderSide(color: Colors.black),
                      ),
                    ),
                    child: Text(
                      '저장',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}