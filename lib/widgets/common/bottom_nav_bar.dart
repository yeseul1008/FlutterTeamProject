import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  void onTab(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      /// 👉 가운데 + 버튼
      floatingActionButton: SizedBox(
        width: 72,
        height: 72,
        child: FloatingActionButton(
          backgroundColor: const Color(0xFFA88AEE),
          shape: const CircleBorder(),
          onPressed: () {
            print("Add button clicked");
          },
          child: const Icon(
            Icons.add,
            size: 40,
            color: Colors.white,
          ),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      /// 👉 하단 네비게이션 바
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.black,
              width: 1,
            ),
          ),
        ),
        child: BottomAppBar(
          color: Colors.white,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          child: SizedBox(
            height: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                navItem(Icons.checkroom, "closet", 0),
                navItem(Icons.calendar_month, "calendar", 1),
                const SizedBox(width: 40),
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

    return InkResponse(
      onTap: () => onTab(index),
      containedInkWell: true,
      radius: 32,
      splashFactory: InkRipple.splashFactory,
      splashColor: selectedColor.withOpacity(0.25),
      highlightColor: selectedColor.withOpacity(0.15),

      child: SizedBox(
        width: 64,
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start, // 🔑 위로 당김
          children: [
            Icon(
              icon,
              size: 40,
              color: isSelected ? selectedColor : defaultColor,
            ),
            const SizedBox(height: 2), // 🔑 간격 최소화
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontSize: 14,
                height: 1.0, // 🔑 줄 높이 고정
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
