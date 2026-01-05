import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int selectedIndex = 0;

  void onTab(BuildContext context, int index) {
    setState(() {
      selectedIndex = index;
    });

    switch (index) {
      case 0:
        context.go('/userWardrobeList');
        break;
      case 1:
        context.go('/userScheduleCalendar');
        break;
      case 2:
        context.go('/userDiaryCards');
        break;
      case 3:
        context.go('/communityMainFeed');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none, // 버튼이 Stack 밖으로 나가도 잘리지 않음
      alignment: Alignment.bottomCenter,
      children: [
        // BottomAppBar를 Container로 감싸 테두리 추가
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.black54, width: 1), // 검정 테두리
            ),
          ),
          child: BottomAppBar(
            color: Colors.transparent, // Container가 배경이므로 투명
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            child: SizedBox(
              height: 70,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  navItem(Icons.checkroom, "closet", 0),
                  navItem(Icons.calendar_month, "calendar", 1),
                  const SizedBox(width: 40), // 노치 공간
                  navItem(Icons.book, "diary", 2),
                  navItem(Icons.groups, "community", 3),
                ],
              ),
            ),
          ),
        ),

        // 가운데 보라색 원형 버튼
        Positioned(
          top: -36, // BottomAppBar 위로 떠오르게
          child: SizedBox(
            width: 72,
            height: 72,
            child: Material(
              shape: const CircleBorder(),
              elevation: 6,
              color: const Color(0xFFA88AEE),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.push('/userWardrobeAdd'),
                child: const Icon(
                  Icons.add,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget navItem(IconData icon, String label, int index) {
    final bool isSelected = selectedIndex == index;
    const Color selectedColor = Color(0xFFA88AEE);
    const Color defaultColor = Colors.black;

    return InkResponse(
      onTap: () => onTab(context, index),
      containedInkWell: true,
      radius: 32,
      splashFactory: InkRipple.splashFactory,
      splashColor: selectedColor.withOpacity(0.25),
      highlightColor: selectedColor.withOpacity(0.15),
      child: SizedBox(
        width: 64,
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 40,
              color: isSelected ? selectedColor : defaultColor,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontSize: 14,
                height: 1.0,
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
