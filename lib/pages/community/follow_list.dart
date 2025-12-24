import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}

/// Home Screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;
  int selectedHeader = 0;

  void onTab(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      /// Header + Content
      body: SafeArea(
        child: Column(
          children: [
            CommunityHeader(
              selectedIndex: selectedHeader,
              onTap: (index) {
                setState(() {
                  context.go('/follow_list.dart');
                  context.go('/question_feed.dart');
                });
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: Center(
                child: Text(
                  selectedHeader == 0
                      ? "Feed"
                      : selectedHeader == 1
                      ? "QnA"
                      : "Follow",
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ),
          ],
        ),
      ),

      /// Floating Button (QnA Add)
      floatingActionButton: SizedBox(
        width: 72,
        height: 72,
        child: FloatingActionButton(
          backgroundColor: Color(0xFFA88AEE),
          shape: CircleBorder(),
          onPressed: (){},
          child: Icon(Icons.add, size: 40),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      /// Bottom Navigation
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.black, width: 1)),
        ),
        child: BottomAppBar(
          shape: CircularNotchedRectangle(),
          child: SizedBox(
            height: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                navItem(Icons.checkroom, "closet", 0),
                navItem(Icons.calendar_month, "calendar", 1),
                SizedBox(width: 40),
                navItem(Icons.book, "diary", 2),
                navItem(Icons.groups, "community", 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget navItem(IconData icon, String label, int index) {
    final bool isSelected = selectedIndex == index;
    const Color selectedColor = Color(0xFFA88AEE);
    const Color defaultColor = Colors.black;

    return InkWell(
      onTap: () => onTab(index),
      child: SizedBox(
        width: 64,
        height: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? selectedColor : defaultColor,
            ),
            SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? selectedColor : defaultColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Community Header
class CommunityHeader extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const CommunityHeader({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _button("feed", 0),
          _button("QnA", 1),
          _button("follow", 2),
        ],
      ),
    );
  }

  Widget _button(String text, int index) {
    final bool isSelected = selectedIndex == index;

    return MainButton(
      width: 96,
      text: text,
      onTap: () => onTap(index),
      backgroundColor:
      isSelected ? const Color(0xFFCAD83B) : Colors.white,
    );
  }
}

/// MainButton
class MainButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final double? width;
  final Color backgroundColor;

  const MainButton({
    super.key,
    required this.text,
    required this.onTap,
    this.width,
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      width: width,
      child: Material(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.black),
            ),
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

///  QnA Add Modal (추가)
class QnaAddModal extends StatelessWidget {
  const QnaAddModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "QnA 작성",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),

          TextField(
            decoration: InputDecoration(
              hintText: "질문 제목을 입력하세요",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: "질문 내용을 입력하세요",
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("등록하기"),
            ),
          ),
        ],
      ),
    );
  }
}
